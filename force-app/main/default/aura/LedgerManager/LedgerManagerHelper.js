/**
 * Created by christopherjohnson on 12/8/17.
 */
({
    getPicklistLedgers: function(component, helper, getLedgers) {
        return new Promise(function(resolve, reject) { 
            var ERR_NO_LEDGER_ACCESS = $A.get("$Label.c.ERR_NO_LEDGER_ACCESS");
            getLedgers.setCallback(this, 
                function(response) {
                    let state = response.getState();
                    if (state === "SUCCESS") {
                        if (response.getReturnValue().length === 0) {
                            reject(new Error(ERR_NO_LEDGER_ACCESS));
                        }
                        component.set("v.ledgers", response.getReturnValue());
                        resolve(response.getReturnValue());
                    }
                    else if (state === "ERROR") {
                        helper.handleErrorReject(response, reject);
                    }                                   
                
                }); 
            $A.enqueueAction(getLedgers);
        });
    },

    getSelectedPicklistLedger: function(component, helper, getSelectedLedger) {
        return new Promise(function(resolve, reject) {
            getSelectedLedger.setCallback(this, function(response) {
                let state = response.getState();
                if (state === "SUCCESS") {
                    if (response.getReturnValue().length > 0 && helper.isResponseIncludesDefault(component, response.getReturnValue())) {
                        component.set("v.selectedLedger", response.getReturnValue());
                        component.set("v.isLoaded", true);
                    }
                    else {
                        helper.setFirstLedgerAsDefault(component);
                    }

                    resolve(response.getReturnValue());
                }
                else if (state === "ERROR") {
                    helper.handleErrorReject(response, reject);
                }
            });

            // Send action off to be executed
            $A.enqueueAction(getSelectedLedger);
        });
    },
    
    setUserActiveLedger: function(component, helper, setLedger) {
        return new Promise(function(resolve, reject) {
            setLedger.setParams({ledgerId: component.get("v.selectedLedger")});

            // Add callback behavior for when response is received
            setLedger.setCallback(this, function(response) {
                let state = response.getState();
                if (state === "SUCCESS") {
                    resolve(response.getReturnValue());
                    const pubsub = component.find('pubsub');
                    pubsub.fireEvent('updatedefaultledger');
                }
                if (state === "ERROR") {
                    helper.handleErrorReject(response, reject);
                }
            });
    
            // Send action off to be executed
            $A.enqueueAction(setLedger);
        }); 
    },

    handleErrorReject: function(response, reject) {
        let errors = response.getError();
        let errorMsg;
        let COMMON_UNKNOWN_ERROR = $A.get("$Label.c.COMMON_UNKNOWN_ERROR");

        if (errors && Array.isArray(errors) && errors.length > 0) {
            if (errors[0] && errors[0].message) {
                errorMsg = errors[0].message;
            }
        } 
        else {
            errorMsg = COMMON_UNKNOWN_ERROR;
        }

        reject(new Error(errorMsg));
    },

    handleErrorPage: function(component, error) {
        component.set("v.isError", true);
        component.set("v.pageErrorMessage", error.message);
    },

    setFirstLedgerAsDefault: function(component) {
        if (component.get("v.ledgers").length > 0) {
            component.set("v.selectedLedger", component.get("v.ledgers")[0].Id);
        }
    },

    isResponseIncludesDefault: function(component, response) {
        let result = false;
        component.get("v.ledgers").forEach((val) => {
            if (val.Id == response) {
                result = true;
            }
        });
        return result;
    }

});