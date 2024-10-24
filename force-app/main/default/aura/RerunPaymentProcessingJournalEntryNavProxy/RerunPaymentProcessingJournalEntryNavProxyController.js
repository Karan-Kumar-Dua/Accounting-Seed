({
    handleBack: function (component, event, helper) {
        window.history.back();
    },
    reInit : function(component, event, helper) {
        $A.get('e.force:refreshView').fire();
    }
})