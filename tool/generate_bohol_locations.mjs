import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';

// Optional compact snapshot generator. All inputs belong to this Flutter app.
const source = new URL('../assets/data/', import.meta.url);
const read = (name) => JSON.parse(readFileSync(new URL(name, source), 'utf8'));
const cities = read('philippine_cities_municipalities.json')
  .filter((item) => item.provinceCode === '071200000')
  .map(({ code, name, provinceCode }) => ({ code, name, parentCode: provinceCode }));
const cityCodes = new Set(cities.map((item) => item.code));
const barangays = read('philippine_barangays.json')
  .filter((item) => item.provinceCode === '071200000' && cityCodes.has(item.cityCode || item.municipalityCode))
  .map(({ code, name, cityCode, municipalityCode }) => ({ code, name, parentCode: cityCode || municipalityCode }));
const target = new URL('../assets/data/', import.meta.url);
mkdirSync(target, { recursive: true });
writeFileSync(new URL('bohol_locations.json', target), `${JSON.stringify({ cities, barangays }, null, 2)}\n`);
console.log(`Generated ${cities.length} Bohol cities/municipalities and ${barangays.length} barangays.`);
