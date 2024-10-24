global with sharing class BillingPDFControllerExt {
    private final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    global Billing__c billBalance {get; private set;}
    global List<Billing_Line__c> billLines {get; private set;}
    private String currencyFormat;
    private String numericFormat;

    global BillingPDFControllerExt(ApexPages.StandardController controller) {
        try {
            if (!Test.isRunningTest()) {
                controller.addFields(
                    new List<String>{
                        'Credit_Memo_Applied_Amount__c',
                        'Cash_Application_Adjustment_Amount__c'
                    }
                );
            }
            Id id = (Id) controller.getId();
            billBalance = queryBillingById(id);
            billBalance.Credit_Memo_Applied_Amount__c =
                billBalance.Received_Amount__c +
                    billBalance.Cash_Application_Adjustment_Amount__c +
                    (billBalance.Credit_Memo_Applied_Amount__c != NULL ? billBalance.Credit_Memo_Applied_Amount__c : 0);

            billLines = queryBillingLinesByBillingId(id);
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    global String getCurrencyFormat() {

        if (currencyFormat == NULL) {
            currencyFormat = '{0,number,' + billBalance.Billing_Format__r.Currency_Format__c + '}';
        }

        return currencyFormat;
    }

    global Boolean getIsInvoiceBilling() {
        return billBalance.Type__c == 'Invoice';
    }

    global Boolean getIsCurrencyFormat() {
        return billBalance.Billing_Format__r.Currency_Format__c != NULL;
    }

    global String getNumericFormat() {

        if (numericFormat == NULL) {
            numericFormat = '{0,number,' + billBalance.Billing_Format__r.Numeric_Format__c + '}';
        }

        return numericFormat;
    }

    global Boolean getIsNumericFormat() {
        return billBalance.Billing_Format__r.Numeric_Format__c != NULL;
    }

    private Billing__c queryBillingById(String billingId) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Type__c',
            'Received_Amount__c',
            'Cash_Application_Adjustment_Amount__c',
            'Credit_Memo_Applied_Amount__c',
            'Billing_Format__r.Currency_Format__c',
            'Billing_Format__r.Numeric_Format__c'
        };

        String queryCondition = 'Id = :billingId';

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (Billing__c) Database.query(theQuery.toSOQL());
    }

    @TestVisible
    private List<Billing_Line__c> queryBillingLinesByBillingId(String billingId) {
        Set<String> billingLineFields = SFDCSecurityUtils.getOnlyCustomAndAccessibleFields(Billing_Line__c.SObjectType);
        Set<String> productFields = getAccessibleProductFields();

        // get the sort field from the URL query
        String sortParam = ApexPages.currentPage().getParameters().get('sortField');
        sortParam = String.isEmpty(sortParam) ? sortParam : String.escapeSingleQuotes(sortParam);
        // from the fields which are sortable select the one which was indicated in the URL query params
        String sortField = getSortFieldApiName(sortParam, billingLineFields, productFields);
        sortField = String.isEmpty(sortField) ? sortField : String.escapeSingleQuotes(sortField);
                    
        List<String> queryFields = new List<String>();
        queryFields.addAll(billingLineFields);
        queryFields.addAll(productFields);
        queryFields.addAll(new List<String>{
            'Employee__r.Name',
            'Project__r.Name',
            'Project_Task__r.Name',
            'Revenue_GL_Account__r.Name'
        });
        if (productFields.contains('Product__r.Name')) {
            queryFields.add('Product__r.Name');
        }

        String queryCondition = 'Billing__c = :billingId ORDER BY ' + String.escapeSingleQuotes(sortField);

        SOQLBuilder theQuery = new SOQLBuilder(Billing_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Billing_Line__c>) Database.query(theQuery.toSOQL());
    }

    @TestVisible
    private static Set<String> getAccessibleProductFields() {
        Set<String> productFields = new Set<String>();
        if (Product2.SObjectType.getDescribe().isAccessible()
                && Billing_Line__c.SObjectType.fields.Product__c.getDescribe().isAccessible()) {

            Set<String> accessibleProductFields = SFDCSecurityUtils.getOnlyAccessibleFields(Product2.SObjectType);
            for (String productField : accessibleProductFields) {
                productFields.add('Product__r.' + productField);
            }
        }
        return productFields;
    }

    @TestVisible
    private static String getSortFieldApiName(String sortParam, Set<String> billingLineFieldApiNames, Set<String> productFieldApiNames) {
        String ns = GlobalVariables.PACKAGE_QUALIFIER;

        // fields which can be sorted
        Set<String> sortableFieldApiNames = new Set<String>();
        sortableFieldApiNames.addAll(billingLineFieldApiNames);
        sortableFieldApiNames.addAll(productFieldApiNames);
        sortableFieldApiNames.add(ns + 'Employee__r.Name');
        sortableFieldApiNames.add(ns + 'Project__r.Name');
        sortableFieldApiNames.add(ns + 'Project_Task__r.Name');
        sortableFieldApiNames.add(ns + 'Revenue_GL_Account__r.Name');
        if (productFieldApiNames.contains('Product__r.Name')) {
            sortableFieldApiNames.add(ns + 'Product__r.Name');
        }

        // the field we are looking for among the sortable fields
        String defaultField = 'Name';
        sortParam = String.isBlank(sortParam) ? defaultField : sortParam;

        // find the field which matches the sort param
        String sortField;
        for (String fieldApiName : sortableFieldApiNames) {
            if (fieldApiName.equalsIgnoreCase(sortParam)) {
                // found an exact match
                // no need to continue searching
                sortField = fieldApiName;
                break;
            } else if (fieldApiName.equalsIgnoreCase(ns + sortParam)) {
                // user may have forgotten to include the namespace prefix
                // keep searching in case there is an exact match
                sortField = fieldApiName;
            }
        }

        // if no match was found, use the default
        sortField = String.isBlank(sortField) ? defaultField : sortField;

        // Swap out lookup fields for their Name field
        if (sortField.equalsIgnoreCase(ns + 'Employee__c')) {
            sortField = ns + 'Employee__r.Name';
        } else if (sortField.equalsIgnoreCase(ns + 'Project__c')) {
            sortField = ns + 'Project__r.Name';
        } else if (sortField.equalsIgnoreCase(ns + 'Project_Task__c')) {
            sortField = ns + 'Project_Task__r.Name';
        } else if (sortField.equalsIgnoreCase(ns + 'Revenue_GL_Account__c')) {
            sortField = ns + 'Revenue_GL_Account__r.Name';
        } else if (sortField.equalsIgnoreCase(ns + 'Product__c')) {
            sortField = ns + 'Product__r.Name';
        }

        return sortField;
    }

}