"""Check source configuration anywhere; inspect compiled device bundles on macOS."""

import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MINIMUM = (16, 0, 0)


def version(value):
    parts = tuple(int(part) for part in str(value).replace('_', '.').split('.'))
    return (parts + (0, 0, 0))[:3]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check_sources():
    project = (ROOT / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
    targets = re.findall(r'IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([^;]+);', project)
    require(bool(targets) and all(t == '16.0' for t in targets),
            f'Project deployment targets must all be 16.0: {targets}')
    require(re.search(r"platform\s+:ios,\s*'16\.0'", (ROOT / 'ios/Podfile').read_text()),
            'Podfile platform must be iOS 16.0')
    with (ROOT / 'ios/Flutter/AppFrameworkInfo.plist').open('rb') as handle:
        require(plistlib.load(handle).get('MinimumOSVersion') == '16.0',
                'Flutter framework minimum must be 16.0')

    metadata = ROOT / '.flutter-plugins-dependencies'
    require(metadata.exists(), 'Run flutter pub get before plugin verification')
    plugins = json.loads(metadata.read_text())['plugins']['ios']
    for plugin in plugins:
        # Resolve only iOS/shared Darwin manifests, excluding macOS-only manifests.
        root = Path(plugin['path'])
        require(root.is_dir(), f"Plugin sources missing: {plugin['name']}")
        manifests = []
        for folder in ('ios', 'darwin'):
            if (root / folder).exists():
                manifests.extend((root / folder).rglob('Package.swift'))
                manifests.extend((root / folder).rglob('*.podspec'))
        declared = []
        for manifest in manifests:
            source = manifest.read_text(encoding='utf-8')
            # Read numeric declarations; CocoaPods/SwiftPM resolve transitive SDKs
            # during the native build. Do not rewrite a dependency's requirements.
            patterns = [
                r'\.iOS\(\s*(?:"([\d.]+)"|\.v([\d_]+))\s*\)',
                r"(?:ios\.deployment_target|platform\s*=\s*:ios,)\s*=?\s*['\"]([\d.]+)['\"]",
            ]
            for pattern in patterns:
                for match in re.findall(pattern, source):
                    value = next((item for item in match if item), '') if isinstance(match, tuple) else match
                    declared.append(value)
                    require(version(value) <= MINIMUM,
                            f"{plugin['name']} requires iOS {value} ({manifest}); keep iOS 16 support")
        if plugin.get('native_build', True):
            require(bool(declared), f"Review unknown native minimum for {plugin['name']}")
        print(f"Plugin {plugin['name']}: declared iOS minima {sorted(set(declared)) or 'Dart-only'}")
    print('Source configuration: iOS 16.0; native dependency resolution still required.')


def output(*command):
    return subprocess.check_output(command, text=True).strip()


def check_binary(binary, exact_minimum=False):
    architectures = output('xcrun', 'lipo', '-archs', str(binary)).split()
    require('arm64' in architectures, f'{binary}: missing arm64 ({architectures})')
    load_commands = output('xcrun', 'otool', '-arch', 'arm64', '-l', str(binary))
    minimums = []
    for block in re.split(r'Load command \d+', load_commands):
        if re.search(r'cmd LC_BUILD_VERSION\b', block):
            platform = re.search(r'\bplatform\s+(\S+)', block)
            require(platform and platform[1].upper() in ('2', 'IOS'),
                    f'{binary}: expected physical iOS platform')
            match = re.search(r'\bminos\s+([\d.]+)', block)
            require(match is not None, f'{binary}: missing minos')
            minimums.append(match[1])
        elif re.search(r'cmd LC_VERSION_MIN_IPHONEOS\b', block):
            minimums.append(re.search(r'\bversion\s+([\d.]+)', block)[1])
    require(bool(minimums), f'{binary}: no iOS minimum load command found')
    for value in minimums:
        # Pad versions to account for tools printing e.g. 16.0.0.
        normalized = version(value)
        require(normalized <= (16, 0, 0), f'{binary}: requires iOS {value}')
        if exact_minimum:
            require(normalized == (16, 0, 0), f'{binary}: minimum must be 16.0, got {value}')
    print(f'{binary}: arm64, iOS minima {minimums}')


def check_app(app):
    require(sys.platform == 'darwin', 'Built bundle verification requires macOS/Xcode')
    require(app.is_dir(), f'Missing app bundle: {app}')
    with (app / 'Info.plist').open('rb') as handle:
        info = plistlib.load(handle)
    require(info.get('MinimumOSVersion') == '16.0', f"App minimum: {info.get('MinimumOSVersion')}")
    require(info.get('CFBundleSupportedPlatforms') == ['iPhoneOS'], 'Expected device app')
    require(1 in info.get('UIDeviceFamily', []), 'App must support iPhone')
    capabilities = info.get('UIRequiredDeviceCapabilities', [])
    require('arm64e' not in capabilities, 'arm64e requirement excludes iPhone 8')
    executable = app / info['CFBundleExecutable']
    require(executable.is_file(), f'Missing executable: {executable}')
    check_binary(executable, exact_minimum=True)
    # Check every embedded Mach-O, including Flutter, plugins, and vendor SDKs.
    for candidate in sorted(app.rglob('*')):
        if candidate.is_file() and candidate != executable:
            with candidate.open('rb') as handle:
                magic = handle.read(4)
            if magic in (b'\xfe\xed\xfa\xce', b'\xce\xfa\xed\xfe',
                         b'\xfe\xed\xfa\xcf', b'\xcf\xfa\xed\xfe',
                         b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca',
                         b'\xca\xfe\xba\xbf', b'\xbf\xba\xfe\xca'):
                check_binary(candidate)
    print('Bundle checks passed. Physical iPhone 8 runtime testing is still required.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path)
    args = parser.parse_args()
    try:
        check_sources()
        if args.app:
            check_app(args.app)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'iOS verification failed: {error}', file=sys.stderr)
        sys.exit(1)
