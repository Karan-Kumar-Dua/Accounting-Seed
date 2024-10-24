({
    onInit: function (component, event, helper) {
        const workspaceAPI = component.find("workspace");
        const INF_RECEIVE_PAYMENT = $A.get("$Label.c.INF_RECEIVE_PAYMENT");
        workspaceAPI.isConsoleNavigation().then(isConsole => {
            if (isConsole) {
                workspaceAPI.getFocusedTabInfo().then(function(response) {
                    const focusedTabId = response.tabId;
                    if (response.isSubtab || response.hasOwnProperty('subtabs')) {
                        workspaceAPI.setTabLabel({
                            tabId: response.isSubtab ? focusedTabId : response.subtabs[0].tabId,
                            label: INF_RECEIVE_PAYMENT
                        });
                        workspaceAPI.setTabIcon({
                            tabId: response.isSubtab ? focusedTabId : response.subtabs[0].tabId,
                            icon: "custom:custom16",
                            iconAlt: INF_RECEIVE_PAYMENT
                        });
                    }
                });
            }
        });
    },

    reInit : function(component, event, helper) {
        $A.get('e.force:refreshView').fire();
    },

    closeMethodInAuraController : function(component, event, helper) {
        $A.get("e.force:closeQuickAction").fire();
    }
})