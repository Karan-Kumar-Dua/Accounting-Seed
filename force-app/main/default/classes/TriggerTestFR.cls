/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private without sharing class TriggerTestFR {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    static testMethod void additionalFinRepRowTriggerTests() {

        TestDataSuite testData = TestDataSuite.getInstance()
        .createReportDefinitions();

        String reportDefId = testData.reportDefs.get(0).Id;

        Financial_Report_Row__c row = new Financial_Report_Row__c();
        row.Financial_Report_Definition__c = reportDefId;
        row.Type__c = 'GL Account';

        //Has no GL Account
        try {
            insert row;
            System.assert(false);
        } catch (DMLException e) {
            System.assert(true);
        }

        //Now has a bad position
        row.GL_Account__c = testData.glAccounts.get(0).Id;
        row.Position__c = -1;

        try {
            insert row;
            System.assert(false);
        } catch (DMLException e) {
            System.assert(true);
        }

        //No reporting group
        row.Position__c = 1;
        row.GL_Account__c = null;
        row.Type__c = 'Reporting Group';

        try {
            insert row;
            System.assert(false);
        } catch (DMLException e) {
            System.assert(true);
        }

        //No calculation
        row.Type__c = 'Calculation Number';

        try {
            insert row;
            System.assert(false);
        } catch (DMLException e) {
            System.assert(true);
        }

        row.Type__c = null;

        try {
            insert row;
            System.assert(false);
        } catch (DMLException e) {
            System.assert(true);
        }

        row.Type__c = 'Fake Value Not Supported';

        try {
            insert row;
            System.assert(false);
        } catch (DMLException e) {
            System.assert(true);
        }
        
    }
    
    static testMethod void additionalFinRepColTriggerTests() {

            TestDataSuite testData = TestDataSuite.getInstance()
        .createReportDefinitions();

        String reportDefId = testData.reportDefs.get(0).Id;
        String ledgerId = testData.ledgers.get(1).Id;

        Financial_Report_Column__c col = new Financial_Report_Column__c();
        col.Financial_Report_Definition__c = reportDefId;

        //No ledger
        col.Type__c = 'Current Period';

        try {
            insert col;
            System.assert(false);
        } catch (DMLException e) {
            System.assert(true);
        }

        //Bad position
        col.Ledger__c = ledgerId;
        col.Position__c = -1;

        try {
            insert col;
            System.assert(false);
        } catch (DMLException e) {
            System.assert(true);
        }

        //No calculation
        col.Position__c = 2;
        col.Type__c = 'Calculation Percentage';

        try {
            insert col;
            System.assert(false);
        } catch (DMLException e) {
            System.assert(true);
        }

        //No type
        col.Type__c = null;

        try {
            insert col;
            System.assert(false);
        } catch (DMLException e) {
            System.assert(true);
        }

        //Invaid type
        col.Type__c = 'Some Invalid Picklist Field';

        try {
            insert col;
            System.assert(false);
        } catch (DMLException e) {
            System.assert(true);
        }
        
    }
}