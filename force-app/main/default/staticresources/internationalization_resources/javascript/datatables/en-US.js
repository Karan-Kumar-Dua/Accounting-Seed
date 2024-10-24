// add AS object to avoid collisions
window.AcctSeed = typeof window.AcctSeed !== 'undefined' ? window.AcctSeed : {};
var AcctSeed = window.AcctSeed;
// add internationalization object if none exists
AcctSeed.i18n = typeof AcctSeed.i18n !== 'undefined' ? AcctSeed.i18n : {};

// export internationalization json to be used by datatables
AcctSeed.i18n.datatables = (function() {
  // en-US is default when "lanaguage" property is undefined
  return undefined;
})();