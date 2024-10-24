/**
 * An interface for handling new row creation in the ALM component.
 */
global interface ALMRowCreateHandler {
    /**
     * Handles new row creation for the ALM component.
     * input: event - create row event data
     * output: the new rows
     */
    List<SObject> createRow(ALMRowCreateEvent event);
}