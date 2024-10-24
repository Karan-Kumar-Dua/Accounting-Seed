public with sharing class PrintCheckRefund {
    private static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    private static final Double DATE_TOP_POSITION = 114;
    private static final Double DATE_RIGHT_POSITION = 48;

    private static final Double AMOUNT_TOP_POSITION = 114;
    private static final Double AMOUNT_RIGHT_POSITION = 2;

    private static final Double AMOUNT_WORDS_TOP_POSITION = 128;
    private static final Double AMOUNT_WORDS_LEFT_POSITION = 2;

    private static final Double PAYEE_TOP_POSITION = 136;
    private static final Double PAYEE_LEFT_POSITION = 8;

    private static final Double PAYEE_ADDRESS_TOP_POSITION = 140.5;
    private static final Double PAYEE_ADDRESS_LEFT_POSITION = 8;

    private static final Double MEMO_TOP_POSITION = 147;
    private static final Double MEMO_LEFT_POSITION = 8;

    public Id recordId {get; set {
        this.recordId = value;
        this.init();
    }}

    public CashReceiptWrapper check {get; private set;}

    private Accounting_Settings__c accountingSettings;

    public PrintCheckRefund() {
        this.accountingSettings = accountingSettingsHandler.getaccountingSettings();
    }

    public Double getDateTopOffset() {
        return DATE_TOP_POSITION + (accountingSettings != NULL && accountingSettings.Date_Top_Offset__c != NULL ? accountingSettings.Date_Top_Offset__c : 0);
    }

    public Double getDateRightOffset() {
        return DATE_RIGHT_POSITION + (accountingSettings != NULL && accountingSettings.Date_Right_Offset__c != NULL ? accountingSettings.Date_Right_Offset__c : 0);
    }

    public Double getAmountTopOffset() {
        return AMOUNT_TOP_POSITION + (accountingSettings != NULL && accountingSettings.Amount_Top_Offset__c != NULL ? accountingSettings.Amount_Top_Offset__c : 0);
    }

    public Double getAmountRightOffset() {
        return AMOUNT_RIGHT_POSITION + (accountingSettings != NULL && accountingSettings.Amount_Right_Offset__c != NULL ? accountingSettings.Amount_Right_Offset__c : 0);
    }

    public Double getAmountWordsTopOffset() {
        return AMOUNT_WORDS_TOP_POSITION + (accountingSettings != NULL && accountingSettings.Amount_Words_Top_Offset__c != NULL ? accountingSettings.Amount_Words_Top_Offset__c : 0);
    }

    public Double getAmountWordsLeftOffset() {
        return AMOUNT_WORDS_LEFT_POSITION + (accountingSettings != NULL && accountingSettings.Amount_Words_Left_Offset__c != NULL ? accountingSettings.Amount_Words_Left_Offset__c : 0);
    }

    public Double getPayeeTopOffset() {
        return PAYEE_TOP_POSITION + (accountingSettings != NULL && accountingSettings.Payee_Top_Offset__c != NULL ? accountingSettings.Payee_Top_Offset__c : 0);
    }

    public Double getPayeeLeftOffset() {
        return PAYEE_LEFT_POSITION + (accountingSettings != NULL && accountingSettings.Payee_Left_Offset__c != NULL ? accountingSettings.Payee_Left_Offset__c : 0);
    }

    public Double getPayeeAddressTopOffset() {
        return PAYEE_ADDRESS_TOP_POSITION + (accountingSettings != NULL && accountingSettings.Payee_Address_Top_Offset__c != NULL ? accountingSettings.Payee_Address_Top_Offset__c : 0);
    }

    public Double getPayeeAddressLeftOffset() {
        return PAYEE_ADDRESS_LEFT_POSITION + (accountingSettings != NULL && accountingSettings.Payee_Address_Left_Offset__c != NULL ? accountingSettings.Payee_Address_Left_Offset__c : 0);
    }

    public Double getMemoTopOffset() {
        return MEMO_TOP_POSITION + (accountingSettings != NULL && accountingSettings.Memo_Top_Offset__c != NULL ? accountingSettings.Memo_Top_Offset__c : 0);
    }

    public Double getMemoLeftOffset() {
        return MEMO_LEFT_POSITION + (accountingSettings != NULL && accountingSettings.Memo_Left_Offset__c != NULL ? accountingSettings.Memo_Left_Offset__c : 0);
    }

    private void init() {
        if (recordId == null) {
            return;
        }
        List<Cash_Receipt__c> cashReceipts = queryCashReceipts();
        this.check = new CashReceiptWrapper(cashReceipts[0]);
    }

    private List<Cash_Receipt__c> queryCashReceipts() {
        List<String> fields = new List<String>{
            'Id',
            'Name',
            'Account__r.Name',
            'Account__r.BillingStreet',
            'Account__r.BillingCity',
            'Account__r.BillingState',
            'Account__r.BillingPostalCode',
            'Account__r.BillingCountry',
            'Amount__c',
            'Applied_Amount__c',
            'Balance__c',
            'Receipt_Date__c',
            'Bank_Account__c',
            'Check_Number__c',
            'Alternate_Payee_Name__c',
            'Payee_Street__c',
            'Payee_City__c',
            'Payee_State__c',
            'Payee_Postal_Code__c',
            'Payee_Country__c',
            'Memo__c',
            'Amount_In_Words__c',
            'Payment_Reference__c',
            'Payment_Type__c'
        };

        String condition = 'Id = :recordId';

        SOQLBuilder q = new SOQLBuilder(Cash_Receipt__c.SObjectType);
        q.assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(fields)
            .setCondition(condition);

        return (List<Cash_Receipt__c>) Database.query(q.toSOQL());
    }

    public with sharing class CashReceiptWrapper  {
        public Cash_Receipt__c cashReceipt {get; private set;}
        public String payeeName {get; private set;}
        public String payeeStreet {get; private set;}
        public String payeeCityStateZip {get; private set;}
        public String payeeCountry {get; private set;}

        public CashReceiptWrapper(Cash_Receipt__c cashReceipt) {
            this.cashReceipt = cashReceipt;
            setAbs();
            setPayeeName();
            setPayeeStreet();
            setPayeeCityStateZip();
            setPayeeCountry();
        }

        // Take absolute value of amount so negative value is not displayed on check
        private void setAbs() {
            if (cashReceipt != null) {
                cashReceipt.Amount__c = Math.abs(cashReceipt.Amount__c);
            }
        }

        // Choose what to use as the payee name
        private void setPayeeName() {
            if (cashReceipt == null) {
                payeeName = '';
            }
            else if (String.isNotBlank(cashReceipt.Alternate_Payee_Name__c)) {
                payeeName = cashReceipt.Alternate_Payee_Name__c;
            }
            else {
                payeeName = cashReceipt.Account__r.Name;
            }
        }

        // Choose what to use as the payee street
        private void setPayeeStreet() {
            if (cashReceipt == null) {
                payeeStreet = '';
            }
            else if (String.isNotBlank(cashReceipt.Payee_Street__c)) {
                payeeStreet = cashReceipt.Payee_Street__c;
            }
            else {
                payeeStreet = cashReceipt.Account__r.BillingStreet;
            }
        }

        // Choose what to use for payee city + state + zip
        private void setPayeeCityStateZip() {
            List<String> cityStateZipParts = new List<String>();
            if (cashReceipt != null) {
                if (String.isNotBlank(cashReceipt.Payee_City__c) && String.isNotBlank(cashReceipt.Payee_State__c)) {
                    cityStateZipParts.add(cashReceipt.Payee_City__c);
                    cityStateZipParts.add(cashReceipt.Payee_State__c);
                    if (String.isNotBlank(cashReceipt.Payee_Postal_Code__c)) {
                        cityStateZipParts.add(cashReceipt.Payee_Postal_Code__c);
                    }
                } else {
                    if (String.isNotBlank(cashReceipt.Account__r.BillingCity)) {
                        cityStateZipParts.add(cashReceipt.Account__r.BillingCity);
                    }
                    if (String.isNotBlank(cashReceipt.Account__r.BillingState)) {
                        cityStateZipParts.add(cashReceipt.Account__r.BillingState);
                    }
                    if (String.isNotBlank(cashReceipt.Account__r.BillingPostalCode)) {
                        cityStateZipParts.add(cashReceipt.Account__r.BillingPostalCode);
                    }
                }
            }
            payeeCityStateZip = String.join(cityStateZipParts, ' ');
        }

        // Choose what to use as the payee country
        private void setPayeeCountry() {
            if (cashReceipt == null) {
                payeeCountry = '';
            }
            else if (String.isNotBlank(cashReceipt.Payee_Country__c)) {
                payeeCountry = cashReceipt.Payee_Country__c;
            }
            else {
                payeeCountry = cashReceipt.Account__r.BillingCountry;
            }
        }
    }

}