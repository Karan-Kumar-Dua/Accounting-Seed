/*
@Deprecated
 */
global with sharing class FinancialReportBatchProcessor implements Database.Batchable<SObject>, Database.Stateful {
    /*
    @Deprecated
    */
    global String query;
    /*
    @Deprecated
    */
    global Integer numrows = 0;
    /*
    @Deprecated
    */
    global FinancialReportGenerator generator;
    /*
    @Deprecated
    */
    global Id reportStubId;
    /*
    @Deprecated
    */
    global List<String> glAccountIds;
    /*
    @Deprecated
    */
    global FinancialReportBatchProcessor(String reportDefId, Integer periodNo, Integer year) {
        
    }

    global Database.QueryLocator start(Database.BatchableContext batchableContext) {
        return NULL;
    }

    global void execute(Database.BatchableContext batchableContext, List<sObject> scope) {

    }

    global void finish(Database.BatchableContext batchableContext) {

    }
    /*
    @Deprecated
    */
    global static testMethod void testBatch() {//still there cause global
        String placeholder = 'test string';
        System.assertEquals('test string', placeholder);
    }
    
}