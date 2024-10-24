({
    doInit: function(component, event, helper) {

        var initOnLoadServerSideCall = component.get("c.initOnLoad");

        // Add callback behavior for when response is received
        initOnLoadServerSideCall.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var recCount = response.getReturnValue();
                if (recCount > 2000) {
                    component.set("v.isAboveLimit", true);
                }
                else if (recCount === 0) {
                    component.set("v.noRecordsFound", true);
                }

                component.set("v.countRec", response.getReturnValue());
            }
            else if (state === 'ERROR') {
                var errors = response.getError();
                if (errors) {
                    var errorMessages = [];
                    errors.forEach(function(item, index) {
                        errorMessages.push(item.message);
                    });
                    component.set("v.errors", errorMessages);
                    component.set("v.isError", true);
                }
            }
        });

        // Send action off to be executed
        $A.enqueueAction(initOnLoadServerSideCall);
    },

    start: function(component, event, helper) {
        component.set("v.isActionStart", true);
        var startStatusProcessing = component.get("c.startStatusProcessing");

        // Add callback behavior for when response is received
        startStatusProcessing.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                if (response.getReturnValue()) {
                    component.set("v.isSuccess", true);
                    component.set("v.isError", false);
                }
                else {
                    component.set("v.isSuccess", false);
                    component.set("v.isError", true);
                }
            }
            else {
                component.set("v.isError", true);
            }
        });

        // Send action off to be executed
        $A.enqueueAction(startStatusProcessing);
    },

    back: function(component, event, helper) {
        window.history.back();
    }
})