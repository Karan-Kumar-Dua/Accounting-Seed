@IsTest
private class LedgerFieldUpdateValidatorTest {

    @IsTest
    private static void testValidatePreventUpdateAction() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new LedgerFieldUpdateValidator();

            Ledger__c newLedger = testData.ledgers[0].clone();
            newLedger.Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH;
            insert newLedger;

            DmlException dmlEx;
            try {
                newLedger.Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
                update newLedger;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.UPDATE_ERROR,
                    new List<String>{
                        sfu.formatFieldStrings(
                            new Set<SObjectField>{
                                Ledger__c.Accounting_Method__c,
                                Ledger__c.Related_Ledger__c,
                                Ledger__c.Active__c,
                                Ledger__c.Accounting_Method_Last_Modified_Date__c
                            }
                        )
                    }
                ),
                dmlEx.getDmlMessage(0)
            );

            newLedger = [
                SELECT
                    Id,
                    Related_Ledger__c,
                    Related_Ledger__r.Accounting_Method__c,
                    Related_Ledger__r.Sales_Tax_Company_Code__c
                FROM Ledger__c
                WHERE Id = :newLedger.Id
            ];
            System.assert(String.isBlank(newLedger.Related_Ledger__r.Sales_Tax_Company_Code__c));

            DmlException dmlEx2;
            try {
                Ledger__c shadowLedger = new Ledger__c(Id = newLedger.Related_Ledger__c);
                shadowLedger.Consolidation_Ledger_ID__c = '123234345';
                update shadowLedger;
            } catch (DmlException ex) {
                dmlEx2 = ex;
            }
            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.UPDATE_ERROR,
                    new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}
                ),
                dmlEx2.getDmlMessage(0)
            );
        }
    }
}