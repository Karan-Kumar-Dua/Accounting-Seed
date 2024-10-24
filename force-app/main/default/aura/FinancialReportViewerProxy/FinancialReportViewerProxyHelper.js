({
  setVarsFromURL : function(cmp) {
      const pageRef = cmp.get("v.pageReference");
      
      const recordId = pageRef.state.AcctSeed__recordId;
      const backTo = pageRef.state.AcctSeed__backTo;

      cmp.set("v.recordId", recordId);
      cmp.set("v.backTo", backTo);
  }
});