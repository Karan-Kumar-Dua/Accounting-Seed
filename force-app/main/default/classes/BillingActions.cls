public with sharing class BillingActions {
    
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;

    public static final String BILLING_FORMAT_ERROR = Label.ERR_BILLING_FORMAT;
    public static final String INVOICE_TYPE = 'Invoice';

    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Billing__c.Currency_Conversion_Rate__c => 6,
        Billing__c.Discount_Percent__c => 2,
        Billing__c.Credit_Memo_Applied_Amount__c => 2
    };

    public static void preventOverAppliedBillings(List<Billing__c> newBillings) {
        for (Billing__c newBilling : newBillings) {
            //Check the Billing's Type. Can be either Invoice or Credit Memo
            Boolean isInvoice = (newBilling.Total__c < 0) ? false : true;

            Decimal totalApplied = (
                newBilling.Received_Amount__c +
                    newBilling.Cash_Application_Adjustment_Amount__c +
                    newBilling.Credit_Memo_Applied_Amount__c
            ).setScale(2, System.RoundingMode.HALF_UP);

            Decimal total = newBilling.Total__c.setScale(2, System.RoundingMode.HALF_UP);
            //Over Application condition depends on Billing's Type
            if ((isInvoice && total < totalApplied) || (!isInvoice && total > totalApplied)) {
                newBilling.addError(
                    String.format(
                        SObjectActions.OVER_APPLIED_ERROR,
                        new List<String>{Billing__c.getSObjectType().getDescribe().getLabel()}
                    )
                );
            }
        }

    }

    public static void requireFields(List<Billing__c> billings) {
        for (Billing__c bill : billings) {
            if (bill.Accounting_Period__c == NULL) {
                bill.Accounting_Period__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
                
            if (bill.Due_Date2__c == NULL) {
                bill.Due_Date2__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            
            if (bill.Billing_Format__c == NULL) {
                bill.Billing_Format__c.addError(BILLING_FORMAT_ERROR);
            }

            if (bill.Ledger__c == NULL) {
                bill.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }
         
    public static void associateBillingFormat(List<Billing__c> billings) {
        Set<Id> ledgerIds = new Set<Id>();
        for (Billing__c bill : billings) {
            if (bill.Billing_Format__c == NULL) {
                if (bill.Ledger__c != NULL) {
                    ledgerIds.add(bill.Ledger__c);
                }
            }
        }
        if (!ledgerIds.isEmpty()) {
            List<Ledger__c> ledgers = LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgersById(ledgerIds);
            Map<Id, Ledger__c> ledgersMap = new Map<Id, Ledger__c>(ledgers);

            for (Billing__c bill : billings) {
                if (bill.Billing_Format__c == NULL
                        && bill.Ledger__c != NULL
                        && ledgersMap.get(bill.Ledger__c) != NULL) {

                    bill.Billing_Format__c = ledgersMap.get(bill.Ledger__c).Default_Billing_Format__c;
                }
            }
        }
    }

    public static void updateDueDateField(List<Billing__c> billings) {
        for (Billing__c bill : billings) {          
            if (bill.Due_Date2__c == NULL) {
                bill.Due_Date2__c = bill.Date__c;
            }
        }
    }
    
    public static void associateAccountFields(List<Billing__c> billings) {
        Map<Id, Account> accountMap = new Map<Id, Account>();

        for (Billing__c bill : billings) {
            if (bill.Customer__c != NULL) {
                accountMap.put(bill.Customer__c, NULL);
            }
        }

        if (!accountMap.isEmpty()) {
            accountMap = new Map<Id, Account>(DomainUtils.getAccountsById(accountMap.keySet()));

            for (Billing__c bill : billings) {
                if (bill.Customer__c != NULL && accountMap.containsKey(bill.Customer__c))  {
                    Account acct = accountMap.get(bill.Customer__c);
                    if (isBillingAddressNotPopulated(bill)) {
                        bill.Billing_Street__c = acct.BillingStreet;
                        bill.Billing_City__c = acct.BillingCity;
                        bill.Billing_State__c = acct.BillingState;
                        bill.Billing_PostalCode__c = acct.BillingPostalCode;
                        bill.Billing_Country__c = acct.BillingCountry;
                    }

                    if (isShippingAddressNotPopulated(bill)) {
                        bill.Shipping_Street__c = acct.ShippingStreet;
                        bill.Shipping_City__c = acct.ShippingCity;
                        bill.Shipping_State__c = acct.ShippingState;
                        bill.Shipping_PostalCode__c = acct.ShippingPostalCode;
                        bill.Shipping_Country__c = acct.ShippingCountry;
                    }
                    
                    if (bill.Billing_Contact__c == NULL) {
                        bill.Billing_Contact__c = acct.Billing_Contact__c;
                    }
                                
                    if (bill.Shipping_Contact__c == NULL) {
                        bill.Shipping_Contact__c = acct.Shipping_Contact__c;
                    }
                    
                    bill.Billing_Terms_Name__c = acct.Billing_Terms_Name__c;

                    if (acct.Billing_Days_Due__c != NULL && bill.Due_Date2__c == NULL) {
                        bill.Due_Date2__c = bill.Date__c + acct.Billing_Days_Due__c.intValue();
                    }
                    else if (acct.Billing_Days_Due__c == NULL && bill.Due_Date2__c == NULL) {
                        bill.Due_Date2__c = bill.Date__c;
                    }
                    
                    if (acct.Billing_Discount_Days_Due__c != NULL
                            && acct.Billing_Discount_Percent__c != NULL
                            && bill.Discount_Due_Date__c == NULL
                            && bill.Discount_Percent__c == NULL) {

                        bill.Discount_Due_Date__c = bill.Date__c + acct.Billing_Discount_Days_Due__c.intValue();
                        bill.Discount_Percent__c = acct.Billing_Discount_Percent__c;
                    }

                    if (bill.Billing_Format__c == NULL) {
                        bill.Billing_Format__c = acct != NULL ? acct.Billing_Format__c : NULL;
                    }
                }
            }
        }
    }
    
    private static Boolean isBillingAddressNotPopulated(Billing__c bill) {
        return String.isBlank(bill.Billing_Street__c)
                    && String.isBlank(bill.Billing_City__c)
                    && String.isBlank(bill.Billing_State__c)
                    && String.isBlank(bill.Billing_PostalCode__c)
                    && String.isBlank(bill.Billing_Country__c);
    }

    private static Boolean isShippingAddressNotPopulated(Billing__c bill) {
        return String.isBlank(bill.Shipping_Street__c)
                    && String.isBlank(bill.Shipping_City__c)
                    && String.isBlank(bill.Shipping_State__c)
                    && String.isBlank(bill.Shipping_PostalCode__c)
                    && String.isBlank(bill.Shipping_Country__c);
    }
    
    public static void calculateCreditMemoAppliedAmount(Map<Id, Billing__c> updateBillingMap) {
        Map<Id, AggregateResult> billCreditMemoMemoMap = new Map<Id, AggregateResult>(DomainUtils.getBillingCreditMemoMemoSumByBilling(updateBillingMap.keySet()));
        Map<Id, AggregateResult> billCreditMemoInvoiceMap = new Map<Id, AggregateResult>(DomainUtils.getBillingCreditMemoInvoiceSumByBilling(updateBillingMap.keySet()));

        for (Billing__c bill : updateBillingMap.values()) {
            bill.Credit_Memo_Applied_Amount__c = 0;

            if (billCreditMemoMemoMap.containsKey(bill.Id)) {
                bill.Credit_Memo_Applied_Amount__c += (Decimal) billCreditMemoMemoMap.get(bill.Id).get('sum');
            }

            if (billCreditMemoInvoiceMap.containsKey(bill.Id)) {
                bill.Credit_Memo_Applied_Amount__c -= (Decimal) billCreditMemoInvoiceMap.get(bill.Id).get('sum');
            }

        }
    }

    public static void setDefaultPaymentProcessor(List<Billing__c> billings) {
        List<Billing__c> billings4Default = new List<Billing__c>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> ledgerIds = new Set<Id>();

        for (Billing__c billing : billings) {
            if (String.isBlank(billing.Payment_Processor__c)) {
                billings4Default.add(billing);
                if (!String.isBlank(billing.Customer__c)) {
                    accountIds.add(billing.Customer__c);
                }
                if (!String.isBlank(billing.Ledger__c)) {
                    ledgerIds.add(billing.Ledger__c);
                }
            }
        }
        if (!billings4Default.isEmpty()) {
            Map<Id,Account> accountsWithPP = new Map<Id, Account>(DomainUtils.getAccountsByIdWithPP(accountIds));
            Map<Id,Ledger__c> ledgersWithPP = new Map<Id, Ledger__c>(DomainUtils.getLedgersByIdWithPP(ledgerIds));
            List<Payment_Processor__c> paymentProcessors =
                    DomainUtils.getPaymentProcessorsById(new Set<Id>{ PaymentGateway.getDefaultPaymentProcessorId() });

            if (!paymentProcessors.isEmpty() || accountsWithPP.size() > 0 || ledgersWithPP.size() > 0) {
                for (Billing__c billing : billings4Default) {
                    if(accountsWithPP.containsKey(billing.Customer__c)){
                        billing.Payment_Processor__c = accountsWithPP.get(billing.Customer__c).Default_Payment_Processor__c;
                    }else if(ledgersWithPP.containsKey(billing.Ledger__c)){
                        billing.Payment_Processor__c = ledgersWithPP.get(billing.Ledger__c).Default_Payment_Processor__c;
                    }else{
                        billing.Payment_Processor__c = paymentProcessors[0]?.Id;
                    }
                }
            }
        }
    }

    public static void setDefaultFields(List<Billing__c> billingList) {
        try {
            String defaultValue = FinancialSuiteUtils.getDefaultPostingStatus(Billing__c.Status__c);

            Id defaultLedgerId = LedgerHandler.getLedgerIdWithSharing();

            for (Billing__c bill : billingList) {
                bill.Status__c = (bill.Status__c == NULL || SObjectActions.isPostedStatus(bill) ? defaultValue : bill.Status__c);
                bill.Closed_Accounting_Period__c = NULL;
                bill.Credit_Memo_Applied_Amount__c = 0;
                bill.PDF_Email_Status__c = 'Unsent';
                bill.Locked_In_AvaTax__c = false;
                SObjectActions.populateLedgerField(bill,defaultLedgerId);
                MultiCurrencyHandler.setCurrencyIsoCodeToUserCurrency(bill);
            }
        }
        catch (Exception ex) {
            for (Billing__c bill : billingList) {
                bill.addError(ex.getMessage(), false);
            }
        }
    }

    public static void createPaymentLink(List<Billing__c> billingsNew, Map<Id,Billing__c> billingsOld) {
        List<Payment_Processor__c> processors = DomainUtils.getActivePaymentProcessors();
        if (processors == null || processors.isEmpty()) {
            return;
        }

        Map<Id, Payment_Processor__c> processorsById = new Map<Id, Payment_Processor__c>(processors);

        // split billings by processor type and collect ids needed for next steps
        List<Billing__c> stripeBillings = new List<Billing__c>();
        List<Billing__c> cardknoxBillings = new List<Billing__c>();
        Set<Id> contactIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> ledgerIds = new Set<Id>();
        Payment_Processor__c processor;
        for (Billing__c billing : billingsNew) {
            if (billing.Type__c == INVOICE_TYPE && processorsById.containsKey(billing.Payment_Processor__c)) {
                processor = processorsById.get(billing.Payment_Processor__c);
                if (processor.Type__c == PaymentProcessorActions.STRIPE_TYPE) {
                    stripeBillings.add(billing);
                } else if (processor.Type__c == PaymentProcessorActions.CARDKNOX_TYPE && String.isNotEmpty(processor.PaymentSite_URL__c)) {
                    cardknoxBillings.add(billing);
                    contactIds.add(billing.Shipping_Contact__c);
                    contactIds.add(billing.Billing_Contact__c);
                    accountIds.add(billing.Customer__c);
                    ledgerIds.add(billing.Ledger__c);
                }
            }
        }

        // process stripe billings
        for (Billing__c billing : stripeBillings) {
            billing.Payment_Site_URL__c = null;
            billing.Payment_Link__c = PaymentLink.getUrl(billing.Id);
        }

        // process cardknox billings
        if (!cardknoxBillings.isEmpty()) {
            Map<Id, Account> accountsById = new Map<Id, Account>(DomainUtils.getAccountsById(accountIds));
            Map<Id, Contact> contactsById = new Map<Id, Contact>(DomainUtils.getContactById(contactIds));
            Map<Id, Ledger__c> ledgersById = new Map<Id, Ledger__c>(DomainUtils.getLedgersById(ledgerIds));
            Decimal balance;
            for (Billing__c billing : cardknoxBillings) {
                billing.Payment_Link__c = null;
                if (isMultiCurrencyEnabled && ledgersById.get(billing.Ledger__c)?.get('CurrencyIsoCode') != billing.get('CurrencyIsoCode')) {
                    billing.Payment_Site_URL__c = Label.COMMON_NA;
                } else {
                    balance = billing.Balance__c;
                    if (billing.Credit_Memo_Applied_Amount__c != billingsOld.get(billing.Id).Credit_Memo_Applied_Amount__c) {
                        // Balance__c (formula field) is not be updated yet in before trigger
                        balance += billingsOld.get(billing.Id).Credit_Memo_Applied_Amount__c; // cancel out old amount
                        balance -= billing.Credit_Memo_Applied_Amount__c; // add new amount
                    }
                    billing.Payment_Site_URL__c = PaymentLink.getUrl(
                        billing, 
                        balance, 
                        accountsById.get(billing.Customer__c), 
                        contactsById, 
                        processorsById.get(billing.Payment_Processor__c)
                    );            
                }  
            }
        }
    }

    //this method will validate changing one Ledger to another only
    //there will be no validation in case if old and/or new value is empty
    public static void preventUpdateLedgerIfAvalaraIsEnabled(Map<Id, SObject> oldRecordsMap, List<SObject> newRecords) {
        if (isMultiCurrencyEnabled && AvaTaxHelper.isAvalaraTaxCalculationEnabled(newRecords)) {
            for (SObject newRecord : newRecords) {
                SObject oldRecord = oldRecordsMap.get(newRecord.Id);
                Id oldRecordLedgerId = (Id) oldRecord.get(PACKAGE_QUALIFIER + 'Ledger__c');
                Id newRecordLedgerId = (Id) newRecord.get(PACKAGE_QUALIFIER + 'Ledger__c');
                if(oldRecordLedgerId != newRecordLedgerId 
                        && LedgerHandler.getInstanceWithSharing(true).getLedgerById(newRecordLedgerId)?.Tax_Settings__r?.Tax_Settings_Method__c 
                            == TaxSettingsActions.AVA_TAX_METHOD 
                        && LedgerHandler.getLedgerCurrency(newRecordLedgerId) != 'USD'){
                    
                    newRecord.addError(Label.LEDGER_UPDATE_IF_AVALARA_IS_ENABLED_ERROR);
                }
            }
        }
    }
    //Method to update Paid Date
    public static void updatePaidDate(Map<Id, Billing__c> billingsByIds){
        Map<Id, Billing__c> clonesByBillingIds = new Map<Id, Billing__c>();
        for (Billing__c billing : billingsByIds.values()) {
            clonesByBillingIds.put(billing.Id, billing.clone());
        }
        Formula.recalculateFormulas(clonesByBillingIds.values());
        Set<Id> billingIds = new  Set<Id>();
        //Get all the billings for the required conditions
        for(Billing__c billing : billingsByIds.values()) {
            Billing__c billingClone = clonesByBillingIds.get(billing.Id);
            if(billingClone.Total__c != 0 && billingClone.Balance__c == 0 && billing.Paid_Date__c == null) {
                billingIds.add(billing.Id);
            }
            if((billingClone.Total__c == 0 || billingClone.Balance__c != 0) && billing.Paid_Date__c != null) {
                billingIds.add(billing.Id);
            }
        }

        if(!billingIds.isEmpty()) {
            List<Billing__c> billingsWithBCRAndBCM = DomainUtils.getBillingCashReceiptsAndBillingCreditMemos(billingIds);
            //Iterate and set the Paid date
            for(Billing__c billing : billingsWithBCRAndBCM) {
                //If Total is not 0, Balance is 0 and Paid date is null then set the Paid Date
                Billing__c billingClone = clonesByBillingIds.get(billing.Id);
                if(billingClone.Total__c != 0 && billingClone.Balance__c == 0 && billing.Paid_Date__c == null) {
                    List<Date> appliedDates = new List<Date>();
                    if (!billing.Billing_Credit_Memos__r.isEmpty()) {
                        appliedDates.add(billing.Billing_Credit_Memos__r[0].Applied_Date__c);
                    }
                    if (!billing.Billing_Credit_Memos1__r.isEmpty()) {
                        appliedDates.add(billing.Billing_Credit_Memos1__r[0].Applied_Date__c);
                    }
                    if (!billing.Billing_Cash_Receipts__r.isEmpty()) {
                        appliedDates.add(billing.Billing_Cash_Receipts__r[0].Applied_Date__c);
                    }
                    appliedDates.sort();
                    if (!appliedDates.isEmpty() && billingsByIds.get(billing.Id) != null) {
                        billingsByIds.get(billing.Id).Paid_Date__c = appliedDates[appliedDates.size() - 1];
                    }
                }

                //If Total is  0, Balance is not 0 and Paid date is not null then set the Paid Date
                if(billingsByIds.get(billing.Id) != null && (billingClone.Total__c == 0 || billingClone.Balance__c != 0 && billing.Paid_Date__c != null)) {
                    billingsByIds.get(billing.Id).Paid_Date__c = null;
                }
            }
        }
    }        
    /**
     * remove payment link if user removes the payment processor reference from billing
     * and not add any new payment processor to the same billing
     */
    public static void removePaymentLinkWhenNoPaymentProcessor(Map<Id,Billing__c> oldBillings,List<Billing__c> billings){
        for(Billing__c billing : billings){
            if(oldBillings.get(billing.Id).Payment_Processor__c != billing.Payment_Processor__c  && 
                        billing.Payment_Processor__c == null){
                billing.Payment_Site_URL__c = '';
            }
        }
    }
}