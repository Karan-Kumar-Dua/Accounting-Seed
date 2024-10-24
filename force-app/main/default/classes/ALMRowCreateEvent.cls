/**
 * Create row event data.
 */
global with sharing class ALMRowCreateEvent {
    /** 
     * The current lines.
     */
    global List<SObject> lines;
    /** 
     * The ID of the header record.
     */
    global String headerId;
    /**
     * The api name of the lines object.
     */
    global String linesObjectApiName;
    /**
     * The api name of the header object.
     */
    global String headerObjectApiName;
    /**
     * The api name of the field on the lines object which
     * forms the relationship to the header object.
     */
    global String parentRelationshipApiName;
    /**
     * The total number of rows to create
     */
    global Decimal createRowsCount;
}