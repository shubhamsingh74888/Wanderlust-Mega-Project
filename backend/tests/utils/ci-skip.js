// CI guard — skips integration tests when MONGODB_URI is not set.
// Usage: replace describe() with maybeDescribe() in integration test files.
const hasDB = !!process.env.MONGODB_URI;
 
if (!hasDB) {
  console.warn(
    '\n[CI] MONGODB_URI not set — integration tests will be skipped.\n' +
    '[CI] To run locally: MONGODB_URI=mongodb://localhost:27017/test npm test\n'
  );
}
 
function maybeDescribe(name, fn) {
  if (hasDB) {
    describe(name, fn);
  } else {
    describe.skip('[SKIPPED - no DB] ' + name, fn);
  }
}
 
module.exports = { maybeDescribe, hasDB };
