({
    closeQuickAction : function(cmp, event, helper) {
        const isNeedRefresh = event.getParam('isNeedRefresh');
        isNeedRefresh && $A.get("e.force:refreshView").fire();
        $A.get("e.force:closeQuickAction").fire();
    }
});