/*
@Deprecated
 */
global with sharing class X1099FileBatch implements Database.Batchable<sObject>, Database.Stateful {
    /*
    @Deprecated
    */
    global String selectedYearName {get; set;}
    /*
    @Deprecated
    */
    global Decimal thresholdAmount {get; set;}
    /*
    @Deprecated
    */
    global X1099FileBatch(String selectedYearName, Decimal thresholdAmount) {

    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        return NULL;
    }

    global void execute(Database.BatchableContext BC, List<sObject> scope) {

    }

    global void finish(Database.BatchableContext BC) {

    }


    /*
    @Deprecated
    */
    global with sharing class RecipientWrapper implements Comparable {
        /*
        @Deprecated
        */
        global sObject recipient {get; set;}
        /*
        @Deprecated
        */
        global String recIdNumber {get; set;}
        /*
        @Deprecated
        */
        global String recName {get; set;}
        /*
        @Deprecated
        */
        global String recStreet {get; set;}
        /*
        @Deprecated
        */
        global String recCity {get; set;}
        /*
        @Deprecated
        */
        global String recState {get; set;}
        /*
        @Deprecated
        */
        global String recZip {get; set;}
        /*
        @Deprecated
        */
        global String recDefault1099box {get; set;}
        /*
        @Deprecated
        */
        global Decimal recAmount {get; set;}
        /*
        @Deprecated
        */
        global RecipientWrapper(Contact contact) {

        }
        /*
        @Deprecated
        */
        global RecipientWrapper(Account account) {

        }

        global Integer compareTo(Object objToCompare) {
            return NULL;
        }

    }

}