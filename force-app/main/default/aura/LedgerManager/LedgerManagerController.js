/**
 * Created by christopherjohnson on 12/8/17.
 */
({
    doInit: function(component, event, helper) {
        let getLedgers = component.get("c.getLedgers");
        let getSelectedLedger = component.get("c.getSelectedLedger");

        helper.getPicklistLedgers(component, helper, getLedgers).then(function() {
            return helper.getSelectedPicklistLedger(component, helper, getSelectedLedger);
        }).catch(function(error) {
            helper.handleErrorPage(component,error);
        });
    },

    setLedger: function(component, event, helper) {
        let setLedgerAction = component.get("c.setSelectedLedger");
        
        helper.setUserActiveLedger(component, helper, setLedgerAction).catch(function(error) {
            helper.handleErrorPage(component, error);
        });
    }

});