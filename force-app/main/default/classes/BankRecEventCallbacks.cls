public with sharing class BankRecEventCallbacks implements Callable {

    public static final String METHOD_NOT_IMPLEMENTED = Label.ERR_METHOD_NOT_IMPLEMENTED;
    public class MethodNotImplementedException extends Exception {}

    public Object call(String action, Map<String, Object> args) {
        List<Consumable> events = (List<Consumable>) args.get('events');
        EventRegistry.RegisteredEvent regEvent = EventRegistry.getRegisteredEventByName(action);
        if (regEvent == EventRegistry.RegisteredEvent.BANK_RECONCILIATION_WORKING_STATUS_CHANGE) {
            BankRecUpdatedActions.handleCompletedStatusChange(events);
        }
        else if (regEvent == EventRegistry.RegisteredEvent.BANK_RECONCILIATION_IN_PROGRESS_STATUS_CHANGE) {
            BankRecUpdatedActions.handleInProgressStatusChange(events);
        }
        else if (regEvent == EventRegistry.RegisteredEvent.BANK_RECONCILIATION_AUTO_CLEAR_RUNNING_STATUS_CHANGE) {
            //do nothing, but prevent it from throwing method not implemented
        }
        else if (regEvent == EventRegistry.RegisteredEvent.BANK_RECONCILIATION_GL_BALANCE_CALCULATED) {
            BankRecUpdatedActions.handleGLAccountBalanceCalculated(events);            
        }
        else if (regEvent == EventRegistry.RegisteredEvent.BANK_RECONCILIATION_CLEAR_ITEMS) {
            BankRecUpdatedActions.handleClearItems(events);
        }
        else {
            throw new MethodNotImplementedException(
                String.format(METHOD_NOT_IMPLEMENTED, new String[] { action })
            );
        }
        return null;
    }

}