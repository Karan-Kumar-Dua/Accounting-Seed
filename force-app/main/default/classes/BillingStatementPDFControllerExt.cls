global with sharing class BillingStatementPDFControllerExt {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String CREDIT_MEMO_TYPE = 'Credit Memo';
    private static final String BCR_REFUND_STATUS = AbstractPostHandler.DEFAULT_POSTING_STATUS_BCR_REFUND;
    private static final String OUTSTANDING_STMT = 'Outstanding Statement';
    private static final String ACTIVITY_STMT = 'Activity Statement';

    global Billing_Format__c statementFormat {get; private set;}
    global Billing__c billBalance {get; private set;}
    global Billing__c billPeriod {get; private set;}
    global Boolean showFootnote {get; private set;}
    private String reportType;
    private Date startDate;
    private Date endDate;
    @TestVisible
    private Date todayDate;
    private String id;
    private String currencyFormat;
    private String ledgerId;
    private String currencyIsoCode;
    private Boolean isAltPayorIncluded;
    private static String sortField;
    private static String pdfType;

    global BillingStatementPDFControllerExt(ApexPages.StandardController controller) {
        try {
            id = ApexPages.currentPage().getParameters().get('id') != NULL
                ? ApexPages.currentPage().getParameters().get('id') : '';

            String formatId = ApexPages.currentPage().getParameters().get('formatId') != NULL
                ? ApexPages.currentPage().getParameters().get('formatId') : '';

            reportType = ApexPages.currentPage().getParameters().get('reportType') != NULL
                ? ApexPages.currentPage().getParameters().get('reportType') : 'activity';

            startDate = ApexPages.currentPage().getParameters().get('startDate') != NULL
                ? Date.valueOf(ApexPages.currentPage().getParameters().get('startDate')) : System.today() - 60;

            endDate = ApexPages.currentPage().getParameters().get('endDate') != NULL
                ? Date.valueOf(ApexPages.currentPage().getParameters().get('endDate')) : System.today();

            ledgerId = ApexPages.currentPage().getParameters().get('ledgerId') != NULL
                    ? ApexPages.currentPage().getParameters().get('ledgerId') : '';

            isAltPayorIncluded =
                ApexPages.currentPage().getParameters().get('includeAltPayor') == 'true' ? true : false;

            currencyIsoCode = ApexPages.currentPage().getParameters().get('currencyIsoCode') != NULL
                ? ApexPages.currentPage().getParameters().get('currencyIsoCode') : '';

            billBalance = new Billing__c(Credit_Memo_Applied_Amount__c = 0, Date__c = endDate);
            billPeriod = new Billing__c(Date__c = startDate, Due_Date2__c = endDate);
            statementFormat = new Billing_Format__c();
            todayDate = !Test.isRunningTest() ? System.today() : NULL;
        
            if (!String.isBlank(formatId)) {
                statementFormat = queryBillingFormatById(formatId);
                sortField = statementFormat.Sort_Field__c != null && statementFormat.Sort_Field__c.startsWith(PACKAGE_QUALIFIER) ? 
                            statementFormat.Sort_Field__c : 
                            statementFormat.Sort_Field__c != null ? 
                            PACKAGE_QUALIFIER + statementFormat.Sort_Field__c : 
                            '';
                pdfType = statementFormat.Type__c;
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }
    
    private Billing_Format__c queryBillingFormatById(String formatId) {
        List<String> queryFields = new List<String>{
            'Id',
            'Image__c',
            'Custom_Footer_Content__c',
            'Company_Street2__c',
            'Company_State__c',
            'Company_PostalCode__c',
            'Company_Name__c',
            'Company_Country__c',
            'Company_City__c',
            'Currency_Format__c',
            'Sort_Field__c',
            'Type__c'
        };

        String queryCondition = 'Id = :formatId';

        SOQLBuilder theQuery = new SOQLBuilder(Billing_Format__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (Billing_Format__c) Database.query(theQuery.toSOQL());
    }

    private List<Billing__c> queryBillings() {
        String billingOrderBy = getOrderByStatement();
       
        List<String> queryFields = new List<String>();
        queryFields.addAll(SFDCSecurityUtils.getOnlyCustomAndAccessibleFields(Billing__c.SObjectType));
        
        String queryCondition = 'Status__c = \'Posted\' AND Customer__c = :id';

        if (!String.isEmpty(ledgerId)) {
            if (LedgerHandler.isLedgerEqualLegacyLedger(ledgerId)) {
                queryCondition += ' AND (Ledger__c = :ledgerId OR Ledger__c = NULL)';
            }
            else {
                queryCondition += ' AND Ledger__c = :ledgerId';
            }
        }

        if (MultiCurrencyHandler.isMultiCurrencyEnabled && !String.isEmpty(currencyIsoCode)) {
            queryCondition += ' AND CurrencyIsoCode = :currencyIsoCode';
        }

        if (reportType == 'activity') {
            queryCondition += ' AND Date__c >= :startDate AND Date__c <= :endDate';
        }
        else {
            queryCondition += ' AND Balance__c != 0 AND Date__c <= :endDate ORDER BY Due_Date2__c';
        }

        queryCondition = billingOrderBy != '' ? queryCondition.substringBefore('ORDER BY') + ' ' + billingOrderBy : queryCondition;

        String bcrSubQueryRelationshipName = GlobalVariables.PACKAGE_QUALIFIER + 'Billing_Cash_Receipts__r';
        String bcmSubQueryRelationshipName = GlobalVariables.PACKAGE_QUALIFIER + 'Billing_Credit_Memos1__r';

        List<String> bcrSubQueryFields = new List<String>{
            'Id',
            'Applied_Date__c',
            'Accounting_Period__r.Start_Date__c',
            'Adjustment_Amount__c',
            'Applied_Amount__c',
            'Billing__r.Name',
            'Cash_Receipt__r.Receipt_Date__c',
            'Cash_Receipt__r.Amount__c',
            'Cash_Receipt__r.Payment_Reference__c',
            'Cash_Receipt__r.Account__c',
            'Status__c'
        };

        String bcrSubQueryCondition = '(Cash_Receipt__r.Receipt_Date__c >= :startDate AND Cash_Receipt__r.Receipt_Date__c <= :endDate) OR (Status__c = :BCR_REFUND_STATUS AND Billing__r.Balance__c = 0)';

        List<String> bcmSubQueryFields = new List<String>{
            'Billing_Invoice__r.Date__c',
            'Billing_Invoice__r.Total__c',
            'Billing_Invoice__r.Name',
            'Billing_Invoice__r.Proprietary_Billing_Number__c',
            'Billing_Credit_Memo__r.Name',
            'Billing_Credit_Memo__r.Proprietary_Billing_Number__c',
            'Billing_Credit_Memo__r.Customer__c',
            'Billing_Credit_Memo__r.Date__c',
            'Amount__c'
        };

        String bcmSubQueryCondition = 'Billing_Credit_Memo__r.Date__c >= :startDate AND Billing_Credit_Memo__r.Date__c <= :endDate';

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        /*
        * setEnforceFLS is set to false because it is redundant to do FLS checks twice.
        * All requested fields were already checked before and only accessible fields will be queried.
        * */
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .subselectQuery(bcrSubQueryRelationshipName, true)
            .selectFields(bcrSubQueryFields)
            .setCondition(bcrSubQueryCondition);
        theQuery
            .subselectQuery(bcmSubQueryRelationshipName, true)
            .selectFields(bcmSubQueryFields)
            .setCondition(bcmSubQueryCondition);

        return (List<Billing__c>) Database.query(theQuery.toSOQL());
    }
    private String getOrderByStatement(){
        List<String> sortByFields = new List<String>();
        sortByFields.add(PACKAGE_QUALIFIER + 'Date__c');
        sortByFields.add(PACKAGE_QUALIFIER + 'Total__c');
        sortByFields.add(PACKAGE_QUALIFIER + 'Balance__c');

        return (String.isBlank(statementFormat.Sort_Field__c) == true || sortByFields.contains(statementFormat.Sort_Field__c) == false ? 
                '' : statementFormat.Type__c == OUTSTANDING_STMT ? 
                'ORDER BY ' + statementFormat.Sort_Field__c : '');
    }
    /**
     * Apply filters to billings for conditions which are 
     * difficult to check using soql.
     */
    private static List<Billing__c> filterBillings(List<Billing__c> billings) {
        if (billings == null || billings.isEmpty()) {
            return billings;
        }

        List<Billing__c> filteredBillings = new List<Billing__c>();
        // apply a series of filters to each billing
        for (Billing__c billing : billings) {
            Boolean pass = filterRefundCreditMemo(billing);
            // additional filters here
            if (pass) {
                filteredBillings.add(billing);
            }
        }

        return filteredBillings;
    }

    /**
     * filter credit memos which are only used in the refund 
     * process to link the incoming (reveived) and 
     * outgoing (refunded) cash receipts
     * 
     * true => passes filter
     * false => fails the filter
     */ 
    private static Boolean filterRefundCreditMemo(Billing__c billing) {
        if (billing.Type__c == CREDIT_MEMO_TYPE 
                && billing.Balance__c == 0
                && billing.Billing_Cash_Receipts__r != null) {
            for (Billing_Cash_Receipt__c bcr : billing.Billing_Cash_Receipts__r) { 
                if (bcr.Status__c == BCR_REFUND_STATUS) {
                    return false;
                }
            }
        }
        return true;
    }

    private List<Billing__c> getBillings() {
        return filterBillings(queryBillings());
    }

    private List<Cash_Receipt__c> queryCashReceipts() {
        List<String> queryFields = new List<String>();
        queryFields.addAll(SFDCSecurityUtils.getOnlyCustomAndAccessibleFields(Cash_Receipt__c.SObjectType));

        String queryCondition =
            'Status__c = \'Posted\' ' +
            'AND Account__c = :id ' +
            'AND Receipt_Date__c >= :startDate ' +
            'AND Receipt_Date__c <= :endDate';

        if (!String.isEmpty(ledgerId)) {
            if (LedgerHandler.isLedgerEqualLegacyLedger(ledgerId)) {
                queryCondition += ' AND (Ledger__c = :ledgerId OR Ledger__c = NULL)';
            }
            else {
                queryCondition += ' AND Ledger__c = :ledgerId';
            }
        }

        if (MultiCurrencyHandler.isMultiCurrencyEnabled && !String.isEmpty(currencyIsoCode)) {
            queryCondition += ' AND CurrencyIsoCode = :currencyIsoCode';
        }

        SOQLBuilder theQuery = new SOQLBuilder(Cash_Receipt__c.SObjectType);
        /*
        * setEnforceFLS is set to false because it is redundant to do FLS checks twice.
        * All requested fields were already checked before and only accessible fields will be queried.
        * */
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Cash_Receipt__c>) Database.query(theQuery.toSOQL());
    }

    
    global List<BillingStatementWrapper> getBillingStatementWrapper() {
        List<BillingStatementWrapper> wrappedBillingStatements = new List<BillingStatementWrapper>();
        this.showFootnote = false;

        try {
            for (Billing__c bill : getBillings()) {
                BillingStatementWrapper bsw = new BillingStatementWrapper();
                bsw.bill = bill;
                bsw.activityType = bill.Type__c == 'Invoice' ? 'billed' : 'credit';
                bsw.balanceProxyObj = new Billing__c(Credit_Memo_Applied_Amount__c = 0, Date__c = bill.Date__c);
                billBalance.Credit_Memo_Applied_Amount__c += bill.Balance__c;

                if (reportType == 'activity') {
                    //process BCRs
                    if (bill.Billing_Cash_Receipts__r != NULL && !bill.Billing_Cash_Receipts__r.isEmpty()) {
                        for (Billing_Cash_Receipt__c bcr : bill.Billing_Cash_Receipts__r) {
                            //create adjustment line
                            if (bcr.Adjustment_Amount__c != NULL && bcr.Adjustment_Amount__c > 0) {
                                BillingStatementWrapper bcrw = new BillingStatementWrapper();
                                bcrw.activityType = 'adjustment';
                                bcrw.balanceProxyObj = new Billing__c(
                                    Credit_Memo_Applied_Amount__c = 0,
                                    Date__c = bcr.Applied_Date__c != NULL ? bcr.Applied_Date__c : bcr.Accounting_Period__r.Start_Date__c
                                );
                                bcrw.bcr = bcr;
                                if (bcr.Cash_Receipt__r.Account__c != id) {
                                    bcrw.isAlternatePayor = true;
                                }
                                if (bcrw.isAlternatePayor && isAltPayorIncluded || !bcrw.isAlternatePayor) {
                                    wrappedBillingStatements.add(bcrw);
                                }
                            }
                            //create CR line for Alternate Payor
                            if (bcr.Cash_Receipt__r.Account__c != id && isAltPayorIncluded) {
                                BillingStatementWrapper bcrw = new BillingStatementWrapper();
                                bcrw.bcr = bcr;
                                bcrw.activityType = 'paid';
                                bcrw.balanceProxyObj = new Billing__c(Credit_Memo_Applied_Amount__c = 0, Date__c = bcr.Cash_Receipt__r.Receipt_Date__c);
                                bcrw.isAlternatePayor = true;
                                wrappedBillingStatements.add(bcrw);
                            }
                        }
                    }
                    //process BCMs
                    if (isAltPayorIncluded && bill.Billing_Credit_Memos1__r != NULL && !bill.Billing_Credit_Memos1__r.isEmpty()) {
                        for (Billing_Credit_Memo__c bcm : bill.Billing_Credit_Memos1__r) {
                            if (bcm.Billing_Credit_Memo__r.Customer__c != id) {
                                BillingStatementWrapper bcmw = new BillingStatementWrapper();
                                bcmw.bcm = bcm;
                                bcmw.activityType = 'credit';
                                bcmw.balanceProxyObj = new Billing__c(Credit_Memo_Applied_Amount__c = 0, Date__c = bcm.Billing_Credit_Memo__r.Date__c);
                                bcmw.isAlternatePayor = true;
                                wrappedBillingStatements.add(bcmw);
                            }
                        }
                    }
                }
                wrappedBillingStatements.add(bsw);
            }

            if (reportType == 'activity') {
                for (Cash_Receipt__c cr : (List<Cash_Receipt__c>) queryCashReceipts()) {
                    BillingStatementWrapper bsw = new BillingStatementWrapper();
                    bsw.receipt = cr;
                    bsw.activityType = 'paid';
                    bsw.balanceProxyObj = new Billing__c(Credit_Memo_Applied_Amount__c = 0, Date__c = cr.Receipt_Date__c);
                    wrappedBillingStatements.add(bsw);
                }
                wrappedBillingStatements.sort();

                Decimal balance = 0;
                for (BillingStatementWrapper bsw : wrappedBillingStatements) {
                    if (bsw.statementSource == 'receipt') {
                        bsw.receipt.Amount__c = bsw.receipt.Amount__c * -1;
                        balance += bsw.receipt.Amount__c;
                    }
                    else if (bsw.statementSource == 'billing-cash-receipt' && bsw.activityType == 'adjustment') {
                        bsw.bcr.Adjustment_Amount__c = bsw.bcr.Adjustment_Amount__c * -1;
                        balance += bsw.bcr.Adjustment_Amount__c;
                    }
                    else if (bsw.statementSource == 'billing-cash-receipt') {
                        bsw.bcr.Applied_Amount__c = bsw.bcr.Applied_Amount__c * -1;
                        balance += bsw.bcr.Applied_Amount__c;
                    }
                    else if (bsw.statementSource == 'billing-credit-memo') {
                        balance += bsw.bcm.Amount__c;
                    }
                    else if (bsw.statementSource == 'billing') {
                        balance += bsw.bill.Total__c;
                    }
                    bsw.balanceProxyObj.Credit_Memo_Applied_Amount__c = balance;
                }
                billBalance.Credit_Memo_Applied_Amount__c = balance.setScale(2, System.RoundingMode.HALF_UP);
            }
            
            //as amount is displayed through 4 fields and for that reason we have merge them in a common field
            combineAmounts(wrappedBillingStatements);            
        }
        catch (Exception ex) {
            throw ex;
        }
        this.showFootnote = isAltPayorIncluded && checkAlternatePayorsRows(wrappedBillingStatements);
        return wrappedBillingStatements;
    }
    private void combineAmounts(List<BillingStatementWrapper> rows){
        for(BillingStatementWrapper row : rows){
            if(row.bill != null){
                row.amount =  row.bill.Total__c;   
           }else if(row.bcr != null){
                row.amount =  row.bcr.Adjustment_Amount__c != null ? row.bcr.Adjustment_Amount__c : row.bcr.Applied_Amount__c;
           }else if(row.receipt != null){
                row.amount =  row.receipt.Amount__c;
           }else if(row.bcm != null){
                row.amount =  row.bcm.Amount__c;
           }
        }
    }
    private Boolean checkAlternatePayorsRows(List<BillingStatementWrapper> rows) {
        Boolean result = false;
        if (rows != NULL && !rows.isEmpty()) {
            for (BillingStatementWrapper row : rows) {
                if (row.isAlternatePayor) {
                    result = true;
                    break;
                }
            }
        }
        return result;
    }


    global String getCurrencyFormat() {

        if (currencyFormat == NULL) {
            String format = statementFormat.Currency_Format__c == NULL ? '###,###,##0.00' : statementFormat.Currency_Format__c;
            currencyFormat = '{0,number,' + statementFormat.Currency_Format__c + '}';
        }

        return currencyFormat;
    }

    global Boolean getIsCurrencyFormat() {
        return statementFormat.Currency_Format__c != NULL;
    }

    global class BillingStatementWrapper implements Comparable {
        global Billing__c bill {get; private set;}
        global Cash_Receipt__c receipt {get; private set;}
        global Billing_Cash_Receipt__c bcr {get; private set;}
        global Billing_Credit_Memo__c bcm {get; private set;}
        global String activityType {get; private set;}
        global Boolean isAlternatePayor {get; private set;}
        public Decimal amount{get; private set;}

        global String statementSource {
            get {
                if (statementSource == NULL) {
                    setStatementSource();
                }
                return statementSource;
            }
            private set;
        }
        global String reference {
            get {
                if (reference == NULL) {
                    setReference();
                }
                return reference;
            }
            private set;
        }
        global Billing__c balanceProxyObj {get; private set;}

        global BillingStatementWrapper() {
            this.isAlternatePayor = false;
        }

        public void setStatementSource() {
            if (this.bill != NULL) {
                statementSource = 'billing';
            }
            else if (this.receipt != NULL) {
                statementSource = 'receipt';
            }
            else if (this.bcr != NULL) {
                statementSource = 'billing-cash-receipt';
            }
            else if (this.bcm != NULL) {
                statementSource = 'billing-credit-memo';
            }
        }

        public void setReference() {
            if (statementSource == 'billing' && !String.isBlank(bill.Proprietary_Billing_Number__c)) {
                reference = bill.Proprietary_Billing_Number__c.left(20);
            }
            else if (statementSource == 'billing' && String.isBlank(bill.Proprietary_Billing_Number__c)) {
                reference = bill.Name;
            }
            else if (statementSource == 'receipt') {
                reference = receipt.Payment_Reference__c.left(20);
            }
            else if (statementSource == 'billing-cash-receipt' && activityType == 'adjustment') {
                reference = bcr.Billing__r.Name;
            }
            else if (statementSource == 'billing-cash-receipt' && activityType == 'paid') {
                reference = bcr.Cash_Receipt__r.Payment_Reference__c.left(20);
            }
            else if (statementSource == 'billing-credit-memo' && !String.isBlank(bcm.Billing_Credit_Memo__r.Proprietary_Billing_Number__c)) {
                reference = bcm.Billing_Credit_Memo__r.Proprietary_Billing_Number__c.left(20);
            }
            else if (statementSource == 'billing-credit-memo' && String.isBlank(bcm.Billing_Credit_Memo__r.Proprietary_Billing_Number__c)) {
                reference = bcm.Billing_Credit_Memo__r.Name.left(20);
            }
        }

        global Integer compareTo(Object compareTo) {
            BillingStatementWrapper compareObject = (BillingStatementWrapper) compareTo;
            
            if(pdfType == ACTIVITY_STMT){
                if(sortField.equalsIgnoreCase(PACKAGE_QUALIFIER +'Running_Balance__c') || sortField.equalsIgnoreCase(PACKAGE_QUALIFIER + Label.COMMON_CAPS_RUNNING_BALANCE)){
                    return comapareAmounts(balanceProxyObj.Credit_Memo_Applied_Amount__c,compareObject.balanceProxyObj.Credit_Memo_Applied_Amount__c);
                }else if(sortField.equalsIgnoreCase(PACKAGE_QUALIFIER +'Amount__c') || sortField.equalsIgnoreCase(PACKAGE_QUALIFIER + Label.COMMON_CAPS_AMOUNT)){
                    return comapareAmounts(amount,compareObject.amount);
                }else if(sortField.equalsIgnoreCase(PACKAGE_QUALIFIER +'Type__c') || sortField.equalsIgnoreCase(PACKAGE_QUALIFIER + Label.COMMON_CAPS_TYPE)){
                    return compareStrings(activityType, compareObject.activityType);
                }else if(sortField.equalsIgnoreCase(PACKAGE_QUALIFIER + 'Date__c') || sortField.equalsIgnoreCase(PACKAGE_QUALIFIER + 'Receipt_Date__c') || sortField.equalsIgnoreCase(PACKAGE_QUALIFIER + Label.COMMON_CAPS_DATE)){
                    return compareDates(balanceProxyObj.Date__c, compareObject.balanceProxyObj.Date__c); 
                }else{
                    return compareDates(balanceProxyObj.Date__c, compareObject.balanceProxyObj.Date__c); 
                }
            }
            return 0;
        }
        private Integer comapareAmounts(Decimal amount, Decimal amountToCompare){
            return amount > amountToCompare ? 1 : amount < amountToCompare ? -1 : 0;
        }
        private Integer compareDates(Date a, Date b) {
            return a > b ? 1 : a < b ? -1 : 0;
        }
        private Integer compareStrings(String a, String b) {
            return a > b ? 1 : a < b ? -1 : 0;
        }
    }
}