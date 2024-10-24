/**
 * An interface for handling changes in the ALM component.
 */
global interface ALMRowChangeHandler {
    /**
     * Handles updates in the ALM rows
     * input: event - row change event
     * output: the updated row
     */
    sObject updateRow(ALMRowChangeEvent event);
}