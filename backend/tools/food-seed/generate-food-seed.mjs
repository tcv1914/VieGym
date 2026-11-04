// Sinh migration seed món ăn (ngày 9) từ dữ liệu Viện Dinh dưỡng đã tải về.
//
//   node backend/tools/food-seed/generate-food-seed.mjs
//
// Đầu vào : data/viendinhduong_mon_an.json (data/crawl_viendinhduong.ps1 tải về, giữ nguyên trường gốc)
// Đầu ra  : backend/src/main/resources/db/migration/V10__seed_foods.sql
//           docs/21-food-catalog.md (báo cáo: số lượng, món bị loại, món ẩn chờ rà)
//
// Quy tắc (docs/20-food-data-policy.md):
// - Số liệu là của MỘT PHẦN ĂN như nguồn công bố; nguồn không ghi khối lượng nên serving_size = NULL.
// - Thiếu kcal/đạm/béo/bột đường hoặc đơn vị lạ → KHÔNG nhập (không điền 0).
// - Năng lượng nguồn lệch > 15% so với 4P + 4C + 9F → nhập nhưng ẩn (is_active = false) chờ rà;
//   không sửa số của nguồn.
// - Chạy lại cho cùng kết quả (UUID v5 theo mã nguồn); SQL dùng ON CONFLICT (code) nên chạy lại
//   không nhân đôi, chỉ cập nhật + tăng revision khi số liệu đổi.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const input = resolve(root, 'data/viendinhduong_mon_an.json');
const sqlOut = resolve(root, 'backend/src/main/resources/db/migration/V10__seed_foods.sql');
const reportOut = resolve(root, 'docs/21-food-catalog.md');

const SITE = 'https://viendinhduong.vn';
const NAMESPACE = 'b6a1e1f2-9c3d-4e5f-8a7b-0c1d2e3f4a5b';
const ATWATER_TOLERANCE = 0.15;
const SERVING_DESCRIPTION = '1 phần ăn theo nguồn';
const SOURCE = 'Viện Dinh dưỡng Quốc gia — Tra cứu giá trị dinh dưỡng món ăn';
const REGION_NAMES = {
  VPF: 'Toàn quốc',
  HAN: 'Hà Nội',
  HAP: 'Hải Phòng',
  SFF: 'Miền Bắc',
};
const MACROS = {
  kcal: { key: 'nang-luong', unit: 'Kcal' },
  protein: { key: 'chat-dam', unit: 'g' },
  fat: { key: 'chat-beo', unit: 'g' },
  carbs: { key: 'chat-bot-duong', unit: 'g' },
};

/** Giống hệt SearchText.normalize (Java); test backend so từng dòng. */
export function normalize(value) {
  return value
    .normalize('NFD')
    .replace(/\p{M}+/gu, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase()
    .replace(/\s+/gu, ' ')
    .trim();
}

function uuidV5(name) {
  const ns = Buffer.from(NAMESPACE.replace(/-/g, ''), 'hex');
  const hash = createHash('sha1').update(ns).update(name, 'utf8').digest();
  hash[6] = (hash[6] & 0x0f) | 0x50;
  hash[8] = (hash[8] & 0x3f) | 0x80;
  const h = hash.subarray(0, 16).toString('hex');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

const sql = (v) => (v === null || v === undefined ? 'NULL' : `'${String(v).replace(/'/g, "''")}'`);

/** Số có tối đa 2 chữ số lẻ, dạng chuỗi chính xác (không qua phép nhân số thực). */
function decimal(value) {
  const text = String(value);
  if (!/^\d+(\.\d+)?$/.test(text)) return null;
  const [int, frac = ''] = text.split('.');
  if (frac.length <= 2) return frac ? `${int}.${frac}` : int;
  // Làm tròn nửa lên ở chữ số thứ 2 (chỉ dùng khi nguồn có > 2 số lẻ).
  return (Math.round(Number(text) * 100) / 100).toFixed(2);
}

function categoryCode(name) {
  return normalize(name)
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 80);
}

const source = JSON.parse(readFileSync(input, 'utf8'));
const retrievedDate = source.retrieved_at.slice(0, 10);
const regionById = Object.fromEntries(source.regions.map((r) => [r.id, r.code]));

const categories = [...source.categories]
  .sort((a, b) => a.ord - b.ord)
  .map((c) => ({
    sourceId: c._id,
    id: uuidV5(`category:${c._id}`),
    code: categoryCode(c.name),
    name: c.name.trim(),
    order: c.ord + 1,
  }));
if (new Set(categories.map((c) => c.code)).size !== categories.length) {
  throw new Error('Trùng mã danh mục');
}
const categoryBySource = Object.fromEntries(categories.map((c) => [c.sourceId, c]));

const foods = [];
const excluded = [];
const flagged = [];
for (const r of source.data) {
  const name = r.name_vi.trim();
  const reasons = [];
  const values = {};
  for (const [field, spec] of Object.entries(MACROS)) {
    const c = r.nutritional_components.find((x) => x.key === spec.key);
    if (!c || c.amount === '' || c.amount === null || c.amount === undefined) {
      reasons.push(`thiếu ${field}`);
      continue;
    }
    if (c.unit_name !== spec.unit) {
      reasons.push(`${field} đơn vị ${c.unit_name} (cần ${spec.unit})`);
      continue;
    }
    const d = decimal(c.amount);
    if (d === null) {
      reasons.push(`${field} không phải số không âm: ${c.amount}`);
      continue;
    }
    values[field] = d;
  }
  const category = categoryBySource[r.category_id];
  const region = regionById[r.food_area_id];
  if (!category) reasons.push('danh mục không có trong nguồn');
  if (!region || !REGION_NAMES[region]) reasons.push('vùng không xác định');
  if (name.length === 0 || name.length > 150) reasons.push('tên rỗng hoặc quá 150 ký tự');
  if (reasons.length > 0) {
    excluded.push({ code: r.code, name, reasons });
    continue;
  }

  const kcal = Number(values.kcal);
  const atwater = 4 * Number(values.protein) + 4 * Number(values.carbs) + 9 * Number(values.fat);
  const deviation = kcal > 0 ? Math.abs(kcal - atwater) / kcal : 1;
  let reviewNote = null;
  if (deviation > ATWATER_TOLERANCE) {
    reviewNote = `Năng lượng nguồn ${values.kcal} kcal lệch ${Math.round(deviation * 100)}% so với 4P+4C+9F = ${atwater.toFixed(1)} kcal; ẩn chờ rà`;
    flagged.push({ code: r.code, name, kcal: values.kcal, atwater: atwater.toFixed(1), deviation });
  }
  const image = typeof r.image === 'string' && r.image.startsWith('/storage/') ? SITE + encodeURI(r.image) : null;
  foods.push({
    id: uuidV5(`food:${r.code}`),
    code: r.code,
    name,
    nameEn: r.name_en?.trim() || null,
    nameSearch: normalize(name),
    categoryId: category.id,
    region,
    ...values,
    sourceRef: `${SOURCE}, mã ${r.code}, truy cập ${retrievedDate}`,
    reviewNote,
    image,
    active: reviewNote === null,
  });
}
foods.sort((a, b) => a.code.localeCompare(b.code));

// ---------- SQL ----------
const lines = [];
lines.push(
  '-- SINH TỰ ĐỘNG bởi backend/tools/food-seed/generate-food-seed.mjs — không sửa tay.',
  `-- Nguồn: ${source.source_url} (tải ${source.retrieved_at}, ${source.total} bản ghi).`,
  `-- Nhập ${foods.length} món (${foods.filter((f) => f.active).length} hiển thị, ${flagged.length} ẩn chờ rà), loại ${excluded.length} món thiếu/sai số liệu.`,
  '-- Chạy lại an toàn: ON CONFLICT (code) không nhân đôi; số liệu đổi thì tăng revision.',
  '',
  'INSERT INTO food_categories (id, code, name, sort_order) VALUES',
  categories.map((c) => `    (${sql(c.id)}, ${sql(c.code)}, ${sql(c.name)}, ${c.order})`).join(',\n'),
  'ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, sort_order = EXCLUDED.sort_order;',
  '',
  'INSERT INTO foods (id, code, name, name_en, name_search, category_id, region, serving_description,',
  '                   kcal_per_serving, protein_per_serving, carbs_per_serving, fat_per_serving,',
  '                   data_quality, source, source_url, image_url, review_note, is_active) VALUES',
  foods
    .map(
      (f) =>
        `    (${sql(f.id)}, ${sql(f.code)}, ${sql(f.name)}, ${sql(f.nameEn)}, ${sql(f.nameSearch)}, ${sql(f.categoryId)}, ` +
        `${sql(f.region)}, ${sql(SERVING_DESCRIPTION)}, ${f.kcal}, ${f.protein}, ${f.carbs}, ${f.fat}, 'SOURCED', ` +
        `${sql(f.sourceRef)}, ${sql(source.source_url)}, ${sql(f.image)}, ${sql(f.reviewNote)}, ${f.active ? 'TRUE' : 'FALSE'})`,
    )
    .join(',\n'),
  'ON CONFLICT (code) DO UPDATE SET',
  '    name = EXCLUDED.name, name_en = EXCLUDED.name_en, name_search = EXCLUDED.name_search,',
  '    category_id = EXCLUDED.category_id, region = EXCLUDED.region,',
  '    serving_description = EXCLUDED.serving_description,',
  '    kcal_per_serving = EXCLUDED.kcal_per_serving, protein_per_serving = EXCLUDED.protein_per_serving,',
  '    carbs_per_serving = EXCLUDED.carbs_per_serving, fat_per_serving = EXCLUDED.fat_per_serving,',
  '    source = EXCLUDED.source, source_url = EXCLUDED.source_url, image_url = EXCLUDED.image_url,',
  '    review_note = EXCLUDED.review_note,',
  '    revision = foods.revision + 1, updated_at = now()',
  // is_active không bị ghi đè: quyết định ẩn/hiện của admin được giữ khi nhập lại.
  'WHERE (foods.name, foods.name_en, foods.category_id, foods.region, foods.kcal_per_serving,',
  '       foods.protein_per_serving, foods.carbs_per_serving, foods.fat_per_serving, foods.image_url)',
  '      IS DISTINCT FROM',
  '      (EXCLUDED.name, EXCLUDED.name_en, EXCLUDED.category_id, EXCLUDED.region, EXCLUDED.kcal_per_serving,',
  '       EXCLUDED.protein_per_serving, EXCLUDED.carbs_per_serving, EXCLUDED.fat_per_serving, EXCLUDED.image_url);',
  '',
);
writeFileSync(sqlOut, lines.join('\n'), 'utf8');

// ---------- Báo cáo ----------
const count = (pred) => foods.filter(pred).length;
const dupNames = Object.values(
  foods.reduce((acc, f) => ((acc[f.nameSearch] ??= []).push(f), acc), {}),
).filter((g) => g.length > 1);
const report = [];
report.push(
  '# Danh mục món ăn — báo cáo nhập dữ liệu',
  '',
  '> Sinh tự động bởi `backend/tools/food-seed/generate-food-seed.mjs`. Quy tắc: `20-food-data-policy.md`.',
  '',
  `Nguồn: [${SOURCE}](${source.source_url}), tải ${source.retrieved_at} bằng \`data/crawl_viendinhduong.ps1\` → \`data/viendinhduong_mon_an.json\`.`,
  '',
  '## 1. Tổng quan',
  '',
  '| Chỉ số | Số lượng |',
  '|---|---:|',
  `| Bản ghi trong nguồn | ${source.total} |`,
  `| Nhập vào \`foods\` | ${foods.length} |`,
  `| — đang hiển thị (\`is_active\`) | ${count((f) => f.active)} |`,
  `| — ẩn chờ rà (lệch năng lượng > ${ATWATER_TOLERANCE * 100}%) | ${flagged.length} |`,
  `| Không nhập (thiếu/sai số liệu) | ${excluded.length} |`,
  `| Chất lượng SOURCED / ESTIMATED / DEMO | ${foods.length} / 0 / 0 |`,
  `| Có link ảnh nguồn | ${count((f) => f.image)} |`,
  `| Tên xuất hiện nhiều lần (khác vùng/khác phần) | ${dupNames.length} tên, ${dupNames.reduce((s, g) => s + g.length, 0)} món |`,
  '',
  '## 2. Theo vùng đo',
  '',
  '| Mã | Vùng | Số món | Hiển thị |',
  '|---|---|---:|---:|',
  ...Object.entries(REGION_NAMES).map(
    ([code, name]) => `| ${code} | ${name} | ${count((f) => f.region === code)} | ${count((f) => f.region === code && f.active)} |`,
  ),
  '',
  '## 3. Theo danh mục (giữ nguyên danh mục nguồn)',
  '',
  '| Mã (`category`) | Tên | Số món | Hiển thị |',
  '|---|---|---:|---:|',
  ...categories.map(
    (c) =>
      `| \`${c.code}\` | ${c.name} | ${count((f) => f.categoryId === c.id)} | ${count((f) => f.categoryId === c.id && f.active)} |`,
  ),
  '',
  `## 4. Ẩn chờ rà (${flagged.length})`,
  '',
  'Năng lượng nguồn lệch nhiều so với 4P + 4C + 9F. Có thể do nhập sai số liệu ở nguồn hoặc thành phần khác (chất xơ, rượu…); chưa đủ căn cứ để sửa nên **giữ nguyên số nguồn** và ẩn.',
  '',
  '| Mã | Tên | kcal nguồn | 4P+4C+9F | Lệch |',
  '|---|---|---:|---:|---:|',
  ...flagged
    .sort((a, b) => b.deviation - a.deviation)
    .map((f) => `| ${f.code} | ${f.name} | ${f.kcal} | ${f.atwater} | ${Math.round(f.deviation * 100)}% |`),
  '',
  `## 5. Không nhập (${excluded.length})`,
  '',
  '| Mã | Tên | Lý do |',
  '|---|---|---|',
  ...excluded
    .sort((a, b) => a.code.localeCompare(b.code))
    .map((e) => `| ${e.code} | ${e.name} | ${e.reasons.join('; ')} |`),
  '',
);
writeFileSync(reportOut, report.join('\n'), 'utf8');

console.log(
  `categories=${categories.length} inserted=${foods.length} active=${count((f) => f.active)} ` +
    `flagged=${flagged.length} excluded=${excluded.length}`,
);
