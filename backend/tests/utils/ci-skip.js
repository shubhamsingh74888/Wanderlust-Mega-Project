const hasDB = !!process.env.MONGODB_URI;
if (!hasDB) { console.warn('\n[CI] No MONGODB_URI — integration tests skipped\n'); }
function maybeDescribe(name, fn) {
  if (hasDB) { describe(name, fn); } else { describe.skip('[SKIPPED-no-DB] ' + name, fn); }
}
module.exports = { maybeDescribe, hasDB };
