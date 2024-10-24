public without sharing class SObjectActions {

    private static final String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;

    @TestVisible
    public static Integer MAX_LINE_COUNT = 1000;
    public static Integer LDV_MAX_LINE_COUNT = 100000;
    public static final Boolean IS_ERP_ENABLED = AccountingSettingsHandler.isERPEnabled();
    public static final String REQUIRED_FIELD_ERROR = Label.ERR_REQUIRED_FIELD;
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String UPDATE_ERROR = Label.ERR_UPDATE_FIELD;

    public static final String MAX_LINE_ERROR = Label.ERR_MAX_LINE;

    public static final String NO_DATED_CONVERSION_RATE_FOUND_ERROR =
            Label.ERR_NO_DATED_CONVERSION_RATE_FOUND;

    public static final String CURRENCY_CONVERSION_RATE_RANGE_ERROR = Label.ERR_CURRENCY_CONVERSION_RATE_RANGE;

    public static final String APPLY_DEPOSIT_ERROR = Label.ERR_APPLY_DEPOSIT;
    public static final String APPLY_RECONCILIATION_ERROR = Label.ERR_APPLY_RECONCILIATION;
    public static final String LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR = Label.ERR_LEDGER_TYPE_TRANSACTIONAL_ONLY;
    public static final String LEDGER_TYPE_TRANSACTIONAL_AND_ELIMINATION_TRANSACTIONAL_ONLY_ERROR = Label.ERR_LEDGER_TYPE_TRANSACTIONAL_AND_ELIMINATION_TRANSACTIONAL_ONLY;
    public static final String LEDGER_UPDATE_IF_AE_ASSOCIATED_ERROR = Label.ERR_LEDGER_UPDATE_IF_AE_ASSOCIATED;
    public static final String OVER_APPLIED_ERROR = Label.ERR_OVER_APPLIED;
    public static final String APPLIED_DATE_OUTSIDE_ACCOUNTING_PERIOD_ERROR =
        Label.ERR_APPLIED_DATE_OUTSIDE_ACCOUNTING_PERIOD;

    public static final Map<Schema.SObjectType, String> APPLIED_ITEMS_ERROR_MAP = new Map<Schema.SObjectType, String> {
        Billing__c.getSObjectType() => Label.ERR_CASH_RECEIPT_APPLIED_CUSTOMER,
        Cash_Receipt__c.getSObjectType() => Label.ERR_BILLING_APPLIED_CUSTOMER,
        Cash_Disbursement__c.getSObjectType() => Label.ERR_PAYABLE_APPLIED_VENDOR
    };

    public static final Map<Schema.SObjectType, String> APPLIED_ACC_PERIOD_ERROR_MAP = new Map<Schema.SObjectType, String> {
        Cash_Disbursement__c.getSObjectType() => Label.ERR_PAYABLE_APPLIED_ACCOUNTING_PERIOD,
        Billing__c.getSObjectType() => Label.ERR_CASH_RECEIPT_APPLIED_ACCOUNTING_PERIOD,
        Cash_Receipt__c.getSObjectType() => Label.ERR_BILLING_APPLIED_ACCOUNTING_PERIOD
    };

    public static final Map<Schema.SObjectType, String> FIELD_CHANGE_WITH_ASSOCIATED_RECORD_ERROR_MAP = new Map<Schema.SObjectType, String> {
        Bank_Deposit__c.getSObjectType() =>
            Label.ERR_UNASSOCIATED_RECORDS,
        Bank_Reconciliation2__c.getSObjectType() =>
            Label.ERR_UNCLEAR_RECORDS,
        Bank_Disbursement__c.getSObjectType() =>
            Label.ERR_UNASSOCIATED_RECORDS
    };

    public static Boolean isPreventNonCloneableFieldsCleaning = false;
    public static Boolean isSkipDefaultGLAccounts = false;

    @TestVisible
    private static final String TYPE_ERROR = Label.ERR_TYPE;

    public static String getPackageQualifierBySObject(List<SObject> objList) {
        String packageQualifier = PACKAGE_QUALIFIER;
        if (!objList.isEmpty() && objList[0].getSObjectType().getDescribe().getName().startsWith('AcctSeedERP__')) {
            packageQualifier = ERP_PACKAGE_QUALIFIER;
        }
        return packageQualifier;
    }

    public static void setCurrencyByLedger(List<SObject> newRecords) {
        if (!MultiCurrencyHandler.isMultiCurrencyEnabled) {
            return;
        }

        for (SObject newRecord : newRecords) {
            if ((Id) newRecord.get('Ledger__c') != NULL) {
                newRecord.put(
                    'CurrencyIsoCode',
                    LedgerHandler.getInstanceWithoutSharing()
                        .getLedgerById((Id) newRecord.get('Ledger__c'))
                        .get('CurrencyIsoCode')
                );
            }
        }
    }

    public static void validateCurrencyConversionRate(List<SObject> newRecords) {
        if (!MultiCurrencyHandler.isMultiCurrencyEnabled) {
            return;
        }
        String packageQualifier = getPackageQualifierBySObject(newRecords);

        for (SObject newRecord : newRecords) {
            if (newRecord.get(packageQualifier + 'Currency_Conversion_Rate__c') != NULL) {//value set by user or changed
                if ( (Decimal) newRecord.get(packageQualifier + 'Currency_Conversion_Rate__c') <= 0) {
                    newRecord.addError(CURRENCY_CONVERSION_RATE_RANGE_ERROR);
                }
            }
            //if there is no Dated Conversion Rate for this billing record - add DML Error
            else if (newRecord.get(packageQualifier + 'Currency_Conversion_Rate__c') == NULL) {
                newRecord.addError(NO_DATED_CONVERSION_RATE_FOUND_ERROR);
            }
        }
    }

    public static void setISOCodeFromParent(List<SObject> newRecords, String masterRecordLookupField) {
        if (!MultiCurrencyHandler.isMultiCurrencyEnabled) {
            return;
        }
        String packageQualifier = getPackageQualifierBySObject(newRecords);
        Set<Id> masterRecordsIds = new Set<Id>();
        for (SObject newRecord : newRecords) {
            if (newRecord.get(packageQualifier + masterRecordLookupField) != NULL) {
                masterRecordsIds.add((Id) newRecord.get(packageQualifier + masterRecordLookupField));
            }
        }

        //get Master Record API Name
        if (masterRecordsIds.size() > 0) {
            String masterRecordAPIName = String.valueOf(new List<Id>(masterRecordsIds)[0].getSobjectType());
            //get Currency Code from Master Record
            List<SObject> masterRecords = Database.query(
                'SELECT Id, CurrencyIsoCode FROM ' + masterRecordAPIName + ' WHERE Id IN :masterRecordsIds'
            );

            Map<Id, SObject> masterRecordsMap = new Map<Id, SObject>(masterRecords);
            //put Currency Code from Master Record to the Detail(Child) record
            for (SObject newRecord : newRecords) {
                Id masterRecordId = (Id) newRecord.get(packageQualifier + masterRecordLookupField);
                if (masterRecordId != NULL && masterRecordsMap.get(masterRecordId) != NULL) {
                    String parentIsoCode = (String) masterRecordsMap.get(masterRecordId).get('CurrencyIsoCode');
                    newRecord.put('CurrencyIsoCode', parentIsoCode);
                }
            }
        }
    }

    public static void setISOCodeFromParentLedger(List<SObject> newRecords, String masterRecordLookupField) {
        if (!MultiCurrencyHandler.isMultiCurrencyEnabled) {
            return;
        }
        String packageQualifier = getPackageQualifierBySObject(newRecords);
        Set<Id> masterRecordsIds = new Set<Id>();
        for (SObject newRecord : newRecords) {
            if (newRecord.get(packageQualifier + masterRecordLookupField) != NULL) {
                masterRecordsIds.add((Id) newRecord.get(packageQualifier + masterRecordLookupField));
            }
        }

        //get Master Record API Name
        if (masterRecordsIds.size() > 0) {
            String masterRecordAPIName = String.valueOf(new List<Id>(masterRecordsIds)[0].getSobjectType());
            //get Currency Code from Master Record
            List<SObject> masterRecords = Database.query(
                'SELECT Id, ' + packageQualifier + 'Ledger__c FROM ' + masterRecordAPIName + ' WHERE Id IN :masterRecordsIds'
            );

            Map<Id, SObject> masterRecordsMap = new Map<Id, SObject>(masterRecords);
            //put Currency Code from Master Record to the Detail(Child) record
            for (SObject newRecord : newRecords) {
                Id masterRecordId = (Id) newRecord.get(packageQualifier + masterRecordLookupField);
                if (masterRecordId != NULL && masterRecordsMap.get(masterRecordId) != NULL) {
                    Id ledgerId = masterRecordsMap.get(masterRecordId).get(packageQualifier + 'Ledger__c') != NULL ? (Id) masterRecordsMap.get(masterRecordId).get(packageQualifier + 'Ledger__c') : LedgerHandler.getLegacyDefaultLedgerId();
                    String parentLedgerIsoCode = LedgerHandler.getLedgerCurrency(ledgerId);
                    newRecord.put('CurrencyIsoCode', parentLedgerIsoCode);
                }
            }
        }
    }

    public static void preventUpdateAction(Map<Id, SObject> oldMap, List<SObject> newList, List<String> nonUpdateFields, Boolean isPreventUpdateOverride) {
        if (!isPreventUpdateOverride) {
            Schema.SObjectType sObjectType = newList.getSObjectType();
            Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();

            for (SObject newObj : newList) {
                SObject oldObj = (oldMap != NULL && oldMap.containsKey(newObj.Id) ? oldMap.get(newObj.Id) : NULL);
                for (String field : nonUpdateFields) {
                    if (!TriggerObserver.getInstance().isUnlockedField(fieldMap.get(field))
                            && (oldObj == NULL && newObj.get(field) != NULL
                                    || oldObj != NULL && oldObj.get(field) != newObj.get(field))) {

                        newObj.addError(String.format(UPDATE_ERROR, new List<String>{FinancialSuiteUtils.formatFieldStrings(sObjectType, nonUpdateFields)}), false);
                    }
                }
            }
        }
    }

    public static void preventUpdateLineCount(List<SObject> objects, SObjectField countFieldToken, Integer lineCount) {
        if (AccountingPeriodActions.isDelarcInProgress) {
            return;
        }
        Integer selectedLineCount = lineCount != NULL ? lineCount : getMaxLineCount(objects);
        for (SObject obj : objects) {
            if (Integer.valueOf(obj.get(countFieldToken)) > selectedLineCount) {
                obj.addError(String.format(MAX_LINE_ERROR, new List<String> {String.valueOf(selectedLineCount)}), false);
            }
        }
    }

    private static Integer getMaxLineCount(List<SObject> objects) {
        Integer lineCount = MAX_LINE_COUNT;
        if (FeatureManagementHandler.isLargeDataVolumeModeEnabled() && !objects.isEmpty() && isAllowLDVMaxLimit(objects[0])) {
            lineCount = LDV_MAX_LINE_COUNT;
        }
        return lineCount;
    }

    private static Boolean isAllowLDVMaxLimit(SObject obj) {
        return obj.getSObjectType() == Billing__c.SObjectType
            || obj.getSObjectType() == Account_Payable__c.SObjectType
            || obj.getSObjectType() == Journal_Entry__c.SObjectType 
            || obj.getSObjectType() == Recurring_Billing__c.SObjectType 
            || obj.getSObjectType() == Recurring_Journal_Entry__c.SObjectType
            || obj.getSObjectType() == Recurring_Account_Payable__c.SObjectType;
    }

    public static void preventSameTimeApplyOnDepositAndReconciliation(Map<Id, SObject> oldObjectMap, List<SObject> newRecords) {
        for (SObject newRecord : newRecords) {
            SObject oldObj = oldObjectMap.get((Id)newRecord.get('Id'));

            if (newRecord.get('Bank_Reconciliation__c') != oldObj.get('Bank_Reconciliation__c') && (Id) newRecord.get('Bank_Reconciliation__c') != NULL) {
                if ((Id) newRecord.get('Bank_Deposit__c') != NULL)
                newRecord.addError(APPLY_DEPOSIT_ERROR);
            }
            if (newRecord.get('Bank_Deposit__c') != oldObj.get('Bank_Deposit__c') && (Id) newRecord.get('Bank_Deposit__c') != NULL) {
                if ((Id) newRecord.get('Bank_Reconciliation__c') != NULL)
                    newRecord.addError(APPLY_RECONCILIATION_ERROR);
            }
        }
    }

    public static void preventUpdateCustomerAndPeriodIfAppliedBCROrApDisb(Map<Id, SObject> oldObjectMap, Map<Id, SObject> newObjectMap, String customerFieldName) {
        Set<Id> objIds = new Set<Id>();
        Set<Id> withCustomerIds = new Set<Id>();
        Set<Id> withAccPeriodIds = new Set<Id>();

        for (SObject newRecord : newObjectMap.values()) {
            Id recordId = (Id)newRecord.get('Id');
            SObject oldObj = oldObjectMap.get(recordId);

            if (newRecord.get(customerFieldName) != oldObj.get(customerFieldName)) {
                withCustomerIds.add(recordId);
            }
            if (newRecord.get('Accounting_Period__c') != oldObj.get('Accounting_Period__c')) {
                withAccPeriodIds.add(recordId);
            }
        }

        objIds.addAll(withCustomerIds);
        objIds.addAll(withAccPeriodIds);

        if (!objIds.isEmpty()) {
            Schema.SObjectType sObjectType = newObjectMap.getSObjectType();
            List<AggregateResult> junctionRecordCount = getJunctionObjectRecordCount(sObjectType, objIds);

            if (!junctionRecordCount.isEmpty()) {
                String parentFieldName = String.valueOf(sObjectType);
                for (AggregateResult agr : junctionRecordCount) {
                    Id recordId = (Id) agr.get(parentFieldName);
                    if (withCustomerIds.contains(recordId)) {
                        newObjectMap.get(recordId).addError(APPLIED_ITEMS_ERROR_MAP.get(sObjectType));
                    }
                    if (withAccPeriodIds.contains(recordId)) {
                        newObjectMap.get(recordId).addError(APPLIED_ACC_PERIOD_ERROR_MAP.get(sObjectType));
                    }
                }
            }
        }
    }

    private static List<AggregateResult> getJunctionObjectRecordCount(Schema.SObjectType sObjectType, Set<Id> objIds) {
        List<AggregateResult> junctionRecordCount = new List<SObject>();
        if (sObjectType == Billing__c.getSObjectType()) {
            junctionRecordCount = DomainUtils.getBillingCashReceiptsByRelatedBillingCount(objIds);
        }
        else if (sObjectType == Cash_Receipt__c.getSObjectType()) {
            junctionRecordCount = DomainUtils.getBillingCashReceiptsByRelatedCashReceiptCount(objIds);
        }
        else if (sObjectType == Cash_Disbursement__c.getSObjectType()) {
            junctionRecordCount = DomainUtils.getApDisbursementsByCashDisbursementCount(objIds);
        }

        return junctionRecordCount;
    }

        public static void preventUpdateFieldWithAssociatedRecords(Map<Id, SObject> oldBankMap, Map<Id, SObject> newBankMap, String fieldName) {
            Boolean isSystemLedgerUpdated;
            if (fieldName == 'CurrencyIsoCode' && !MultiCurrencyHandler.isMultiCurrencyEnabled) {
                return;
            }
            Set<Id> bankIds = new Set<Id>();
            for (Id brId : newBankMap.keySet()) {
                isSystemLedgerUpdated = false;
                if (fieldName == 'Ledger__c'
                    && oldBankMap.get(brId).get(fieldName) == NULL
                    && newBankMap.get(brId).get(fieldName) == LedgerHandler.getLegacyDefaultLedgerId()) {
                    isSystemLedgerUpdated = true;
                }
                if (newBankMap.get(brId).get(fieldName) != oldBankMap.get(brId).get(fieldName) && !isSystemLedgerUpdated) {
                    bankIds.add(brId);
                }
            }
            if (!bankIds.isEmpty()) {
                Schema.SObjectType sObjectType = newBankMap.getSObjectType();
                List<SObject> bankRecChildRecords = new List<SObject>();
                if (sObjectType == Bank_Deposit__c.getSObjectType()) {
                    bankRecChildRecords = DomainUtils.getBankDepositsById(bankIds);
                }
                if (sObjectType == Bank_Reconciliation2__c.getSObjectType()) {
                    bankRecChildRecords = DomainUtils.getBankReconciliationsById(bankIds);
                }

                for (SObject br : bankRecChildRecords) {
                    if (((br.getSObjects('Cash_Receipts__r') != NULL) && !((List<SObject>) br.getSObjects('Cash_Receipts__r')).isEmpty()) ||
                            ((br.getSObjects('Journal_Entry_Lines__r') != NULL) && !((List<SObject>) br.getSObjects('Journal_Entry_Lines__r')).isEmpty()) ||
                            sObjectType == Bank_Reconciliation2__c.getSObjectType() &&
                            (((br.getSObjects('Cash_Disbursements__r') != NULL) && !((List<SObject>) br.getSObjects('Cash_Disbursements__r')).isEmpty()) ||
                            ((br.getSObjects('Bank_Deposits__r') != NULL) && !((List<SObject>) br.getSObjects('Bank_Deposits__r')).isEmpty()))) {

                        newBankMap.get(br.Id).addError(
                                String.format(
                                        FIELD_CHANGE_WITH_ASSOCIATED_RECORD_ERROR_MAP.get(sObjectType),
                                        new List<String> {sObjectType.getDescribe().fields.getMap().get(PACKAGE_QUALIFIER + fieldName).getDescribe().getLabel()}
                                ), false);
                    }
                }
            }
        }

    public static void preventUpdateLedgerIfAmortizationEntry(Map<Id, SObject> oldRecordMap, Map<Id,SObject> newRecordMap, String relatedField) {

        Set<Id> relatedRecordsIds = new Set<Id>();

        for (SObject newRecord : newRecordMap.values()) {
            SObject oldRecord = oldRecordMap.get(newRecord.Id);
            if (oldRecord.get('Ledger__c') != NULL && newRecord.get('Ledger__c') != oldRecord.get('Ledger__c')) {
                relatedRecordsIds.add(newRecord.Id);
            }
        }

        if (!relatedRecordsIds.isEmpty()) {
            relatedField = PACKAGE_QUALIFIER + relatedField;
            for (AggregateResult agr : DomainUtils.getScheduledRevenueExpensesByRelatedObjectCount(relatedRecordsIds,relatedField)) {
                Id recordId = (Id) agr.get(relatedField);
                newRecordMap.get(recordId).addError(LEDGER_UPDATE_IF_AE_ASSOCIATED_ERROR);
            }
        }
    }
  
    /* Implemenation of binary search to find least greatest date index in sorted date list
    *  based on date value parameter
    */
    private static Integer searchLeastGreatestDate(Date[] dateList, Date value) {
        if (dateList.isEmpty()) {
            return -1;
        }
        if (value < dateList[0]) {
            return -1;
        }
        if (value > dateList[dateList.size()-1]) {
            return -1;
        }

        Integer first = 0;
        Integer last = dateList.size() - 1;

        while (first <= last) {
            Integer mid = (last + first) / 2;

            if (value < dateList[mid]) {
                last = mid - 1;
            } 
            else if (value > dateList[mid]) {
                first = mid + 1;
            } 
            else {
                return mid;
            }
        }

        return (dateList[first].daysBetween(value)) < (value.daysBetween(dateList[last])) ? first : last;
    }

    public static void setAccountingPeriod(SObject[] objects, SObjectField dateField) {
        List<Date> sortedDates = new List<Date>();
        List<Accounting_Period__c> periods = new List<Accounting_Period__c>();
        Set<Date> dates = new Set<Date>();

        List<SObject> updateObjects = new List<SObject>();
        for (SObject obj : objects) {
            if (obj.get('Accounting_Period__c') == NULL) {
                dates.add((Date)obj.get(dateField));
                updateObjects.add(obj);
            }
        }

        if (!dates.isEmpty()) {
            for (Accounting_Period__c period : [SELECT Id, Start_Date__c, End_Date__c 
                                                FROM Accounting_Period__c
                                                WHERE Start_Date__c <= :dates
                                                AND End_Date__c >= :dates
                                                ORDER BY Start_Date__c ASC]) {
                sortedDates.add(period.Start_Date__c);
                sortedDates.add(period.End_Date__c);
                periods.add(period);
            }

            if (!sortedDates.isEmpty()) {
                for (SObject obj : updateObjects) {
                    Date objDate = (Date) obj.get(dateField);
                    Integer periodsListIndex = searchLeastGreatestDate(sortedDates, objDate);
                    if (periodsListIndex >= 0) {
                        Id periodId = periods[periodsListIndex/2].Id;
                        obj.put('Accounting_Period__c',periodId);
                    }
                }
            }
        }
    }

    public static void associateWithCashFlowCategory (List<SObject> newRecords) {
        if (AccountingSettingsHandler.getAccountingSettings().Enable_Cash_Flow_Statement__c) {
            List<Cash_Receipt__c> crWithoutCashFlowCategory = new List<Cash_Receipt__c>();
            List<Cash_Disbursement__c> cdWithoutCashFlowCategory = new List<Cash_Disbursement__c>();
            List<SObject> jelOrRjelWithoutCashFlowCategory = new List<SObject>();
            for (SObject newRecord : newRecords) {
                if (newRecord.get('Cash_Flow_Category__c') == NULL) {
                    switch on newRecord {
                        when Cash_Receipt__c cr {
                            crWithoutCashFlowCategory.add(cr);
                        }
                        when Cash_Disbursement__c cd {
                            cdWithoutCashFlowCategory.add(cd);
                        }
                        when Journal_Entry_Line__c je {
                            jelOrRjelWithoutCashFlowCategory.add(je);
                        }
                        when Recurring_Journal_Entry_Line__c rje {
                            jelOrRjelWithoutCashFlowCategory.add(rje);
                        }
                    }
                }
            }

            if (!crWithoutCashFlowCategory.isEmpty()) {
                CashReceiptActions.associateWithCashFlowCategory(crWithoutCashFlowCategory);
            }

            if (!cdWithoutCashFlowCategory.isEmpty()) {
                CashDisbursementActions.associateWithCashFlowCategory(cdWithoutCashFlowCategory);
            }

            if (!jelOrRjelWithoutCashFlowCategory.isEmpty()) {
                JournalEntryLineActions.associateWithCashFlowCategory(jelOrRjelWithoutCashFlowCategory);
            }
        }
    }

    /*
    Currently this method handles only Bank Id field but can be extended later to handle other fields
    selected according to certain criteria(Ex. all ExternalId fields)
    */
    public static void handleNonCloneableFields(List<SObject> newRecords) {
        if (isPreventNonCloneableFieldsCleaning) {
            return;
        }

        Boolean isBankDeposit = !newRecords.isEmpty() && newRecords[0].getSObjectType() == Bank_Deposit__c.getSObjectType();

        for (SObject newRecord : newRecords) {
            if (newRecord.get('Bank_Id__c') != NULL) {
                newRecord.put('Bank_Id__c', NULL);
            }
            if (!isBankDeposit && newRecord.get('Bank_Transaction__c') != NULL) {
                newRecord.put('Bank_Transaction__c', NULL);
            }
        }
    }

    /*
    * This is trigger level validation of Accounting Variable type field
    * We use it instead of required lookup filters for GLAVs fields on
    * PRODUCT and OPPORTUNITYLINEITEM records
    */
    public static void validateGLVariableType(SObject[] objs) {
        Map<Id, List<SObject>> glVar1Map = new Map<Id, List<SObject>>();
        Map<Id, List<SObject>> glVar2Map = new Map<Id, List<SObject>>();
        Map<Id, List<SObject>> glVar3Map = new Map<Id, List<SObject>>();
        Map<Id, List<SObject>> glVar4Map = new Map<Id, List<SObject>>();

        for (SObject obj : objs) {

            Id value = (Id) obj.get('GL_Account_Variable_1__c');
            if (value != NULL) {
                if (glVar1Map.containsKey(value)) {
                    glVar1Map.get(value).add(obj);
                }
                else {
                    glVar1Map.put(value, new List<SObject>{obj});
                }
            }

            value = (Id) obj.get('GL_Account_Variable_2__c');
            if (value != NULL) {
                if (glVar2Map.containsKey(value)) {
                    glVar2Map.get(value).add(obj);
                }
                else {
                    glVar2Map.put(value, new List<SObject>{obj});
                }
            }

            value = (Id) obj.get('GL_Account_Variable_3__c');
            if (value != null) {
                if (glVar3Map.containsKey(value)) {
                    glVar3Map.get(value).add(obj);
                }
                else {
                    glVar3Map.put(value, new List<SObject>{obj});
                }
            }

            value = (Id) obj.get('GL_Account_Variable_4__c');
            if (value != NULL) {
                if (glVar4Map.containsKey(value)) {
                    glVar4Map.get(value).add(obj);
                }
                else {
                    glVar4Map.put(value, new List<SObject>{obj});
                }
            }
        }

        Schema.SObjectType oType = objs.getSObjectType();
        for (Accounting_Variable__c av : [  SELECT Id, Type__c
                                            FROM Accounting_Variable__c
                                            WHERE (Id IN :glVar1Map.keySet()
                                                    OR Id IN :glVar2Map.keySet()
                                                    OR Id IN :glVar3Map.keySet()
                                                    OR Id IN :glVar4Map.keySet())]) {

            if (glVar1Map.containsKey(av.Id) && av.Type__c != AccountingVariableActions.ACCOUNTING_VARIABLE_TYPE_1) {
                for (SObject obj : glVar1Map.get(av.Id)) {
                    addErrorMessage1(obj, oType);
                }
            }

            if (glVar2Map.containsKey(av.Id) && av.Type__c != AccountingVariableActions.ACCOUNTING_VARIABLE_TYPE_2) {
                for (SObject obj : glVar2Map.get(av.Id)) {
                    addErrorMessage2(obj, oType);
                }
            }

            if (glVar3Map.containsKey(av.Id) && av.Type__c != AccountingVariableActions.ACCOUNTING_VARIABLE_TYPE_3) {
                for (SObject obj : glVar3Map.get(av.Id)) {
                    addErrorMessage3(obj, oType);
                }
            }

            if (glVar4Map.containsKey(av.Id) && av.Type__c != AccountingVariableActions.ACCOUNTING_VARIABLE_TYPE_4) {
                for (SObject obj : glVar4Map.get(av.Id)) {
                    addErrorMessage4(obj, oType);
                }
            }
        }
    }

    private static void addErrorMessage1(SObject obj, SObjectType oType) {
        String errorMessage = String.format(TYPE_ERROR, new List<String>{'1'});
        if (oType == Product2.SObjectType) {
            ((Product2) obj).GL_Account_Variable_1__c.addError(errorMessage);
        }
        else if (oType == OpportunityLineItem.SObjectType) {
            ((OpportunityLineItem) obj).GL_Account_Variable_1__c.addError(errorMessage);
        }
    }

    private static void addErrorMessage2(SObject obj, SObjectType oType) {
        String errorMessage = String.format(TYPE_ERROR, new List<String>{'2'});
        if (oType == Product2.SObjectType) {
            ((Product2) obj).GL_Account_Variable_2__c.addError(errorMessage);
        }
        else if (oType == OpportunityLineItem.SObjectType) {
            ((OpportunityLineItem) obj).GL_Account_Variable_2__c.addError(errorMessage);
        }
    }

    private static void addErrorMessage3(SObject obj, SObjectType oType) {
        String errorMessage = String.format(TYPE_ERROR, new List<String>{'3'});
        if (oType == Product2.SObjectType) {
            ((Product2) obj).GL_Account_Variable_3__c.addError(errorMessage);
        }
        else if (oType == OpportunityLineItem.SObjectType) {
            ((OpportunityLineItem) obj).GL_Account_Variable_3__c.addError(errorMessage);
        }
    }

    private static void addErrorMessage4(SObject obj, SObjectType oType) {
        String errorMessage = String.format(TYPE_ERROR, new List<String>{'4'});
        if (oType == Product2.SObjectType) {
            ((Product2) obj).GL_Account_Variable_4__c.addError(errorMessage);
        }
        else if (oType == OpportunityLineItem.SObjectType) {
            ((OpportunityLineItem) obj).GL_Account_Variable_4__c.addError(errorMessage);
        }
    }

    public static void populateGLAVsFromAccountOrProduct(List<SObject> newRecords) {
        populateGLAVsFromAccountOrProduct(newRecords, isSkipDefaultGLAccounts);
    }

    public static void populateGLAVsFromAccountOrProduct(List<SObject> newRecords, Boolean isSkipAllLogicAndValidations) {
        if (!isSkipAllLogicAndValidations) {
            Set<Id> sourceRecordIds = new Set<Id>();//Ids of records from where Account content can be taken
            Schema.SObjectType objType;
            Map<Id, Product2> productMap;
            Map<Id, Account> accountSourceMap = new Map<Id, Account>();
            Map<String, Schema.SObjectType> globalDescribeERP = new Map<String, Schema.SObjectType>();

            if (IS_ERP_ENABLED) {
                globalDescribeERP = Schema.getGlobalDescribe();
            }

            //Some records have direct Account lookup field
            //and some records have Account lookup field on Master record
            for (SObject newRecord : newRecords) {

                if (newRecords.getSObjectType() == Billing_Line__c.SObjectType
                        && newRecord.get('Billing__c') != NULL) {

                    sourceRecordIds.add((Id) newRecord.get('Billing__c'));
                }
                else if (newRecords.getSObjectType() == Account_Payable_Line__c.SObjectType
                        && newRecord.get('Account_Payable__c') != NULL) {

                    sourceRecordIds.add((Id) newRecord.get('Account_Payable__c'));
                }
                else if (newRecords.getSObjectType() == Recurring_Billing_Line__c.SObjectType
                        && newRecord.get('Recurring_Billing__c') != NULL) {

                    sourceRecordIds.add((Id) newRecord.get('Recurring_Billing__c'));
                }
                else if (newRecords.getSObjectType() == Recurring_Account_Payable_Line__c.SObjectType
                        && newRecord.get('Recurring_Account_Payable__c') != NULL) {

                    sourceRecordIds.add((Id) newRecord.get('Recurring_Account_Payable__c'));
                }
                else if (newRecords.getSObjectType() == Cash_Disbursement__c.SObjectType
                        && newRecord.get('Vendor__c') != NULL) {

                    sourceRecordIds.add((Id) newRecord.get('Vendor__c'));
                }
                else if (newRecord.getPopulatedFieldsAsMap().containsKey(PACKAGE_QUALIFIER + 'Account__c') && newRecord.get('Account__c') != NULL) {
                    sourceRecordIds.add((Id) newRecord.get('Account__c'));
                }
                else if (IS_ERP_ENABLED && (newRecords.getSObjectType() == globalDescribeERP.get(ERP_PACKAGE_QUALIFIER + 'Sales_Order_Line__c') && newRecord.get(ERP_PACKAGE_QUALIFIER + 'Sales_Order__c') != NULL)) {
                    sourceRecordIds.add((Id) newRecord.get(ERP_PACKAGE_QUALIFIER + 'Sales_Order__c'));
                }
                else if (IS_ERP_ENABLED && (newRecords.getSObjectType() == globalDescribeERP.get(ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Line__c') && newRecord.get(ERP_PACKAGE_QUALIFIER + 'Purchase_Order__c') != NULL)) {
                    sourceRecordIds.add((Id) newRecord.get(ERP_PACKAGE_QUALIFIER + 'Purchase_Order__c'));
                }
                else if (newRecords.getSObjectType() == Project_Task__c.SObjectType
                    && newRecord.get('Project__c') != NULL) {

                    sourceRecordIds.add((Id) newRecord.get('Project__c'));
                }
            }

            objType = (!sourceRecordIds.isEmpty())
                    ? new List<Id>(sourceRecordIds)[0].getSobjectType()//in case Account from parent
                    : Account.getSObjectType();//in case direct Account lookup

            accountSourceMap = getAccountSourceMap(sourceRecordIds, objType);
            productMap = getProductSourceMap(newRecords);

            String glav1FieldApiName = addNamespacePrefixToFieldName('GL_Account_Variable_1__c', objType);
            String glav2FieldApiName = addNamespacePrefixToFieldName('GL_Account_Variable_2__c', objType);
            String glav3FieldApiName = addNamespacePrefixToFieldName('GL_Account_Variable_3__c', objType);
            String glav4FieldApiName = addNamespacePrefixToFieldName('GL_Account_Variable_4__c', objType);
            String productFieldFullApiName = addNamespacePrefixToFieldName('Product__c', newRecords.getSObjectType());

            //now go through all new records and try to populate default GLAVs from related Account OR Product
            String sourceRecordLookupName = getSourceRecordLookupAPIName(objType);

            //Cash Disbursement has different Account lookup field name
            if (newRecords.getSObjectType() == Cash_Disbursement__c.SObjectType) {
                sourceRecordLookupName = 'Vendor__c';
            }

            String fullyQualifiedSourceRecordLookupName = addNamespacePrefixToFieldName(sourceRecordLookupName, newRecords.getSObjectType());

            for (SObject newRecord : newRecords) {
                Map<String, Object> newRecordFieldMap = newRecord.getPopulatedFieldsAsMap();

                if (newRecord.get(glav1FieldApiName) == NULL) {
                    if (newRecordFieldMap.containsKey(fullyQualifiedSourceRecordLookupName)
                            && SObjectActions.canTakeDefaultGLAVFromSource((Id) newRecord.get(sourceRecordLookupName), accountSourceMap, 1)) {
                        newRecord.put(
                                glav1FieldApiName,
                                accountSourceMap.get((Id) newRecord.get(sourceRecordLookupName)).GL_Account_Variable_1__c
                        );
                    }
                    else if (!productMap.isEmpty()
                            && newRecordFieldMap.containsKey(productFieldFullApiName)
                            && SObjectActions.canTakeDefaultGLAVFromSource((Id) newRecord.get(productFieldFullApiName), productMap, 1)) {

                        newRecord.put(
                                glav1FieldApiName,
                                productMap.get((Id) newRecord.get(productFieldFullApiName)).GL_Account_Variable_1__c
                        );
                    }
                }

                if (newRecord.get(glav2FieldApiName) == NULL) {
                    if (newRecordFieldMap.containsKey(fullyQualifiedSourceRecordLookupName)
                            && SObjectActions.canTakeDefaultGLAVFromSource((Id) newRecord.get(sourceRecordLookupName), accountSourceMap, 2)) {

                        newRecord.put(
                                glav2FieldApiName,
                                accountSourceMap.get((Id) newRecord.get(sourceRecordLookupName)).GL_Account_Variable_2__c
                        );
                    }
                    else if (!productMap.isEmpty()
                            && newRecordFieldMap.containsKey(productFieldFullApiName)
                            && SObjectActions.canTakeDefaultGLAVFromSource((Id) newRecord.get(productFieldFullApiName), productMap, 2)) {

                        newRecord.put(
                                glav2FieldApiName,
                                productMap.get((Id) newRecord.get(productFieldFullApiName)).GL_Account_Variable_2__c
                        );
                    }
                }

                if (newRecord.get(glav3FieldApiName) == NULL) {
                    if (newRecordFieldMap.containsKey(fullyQualifiedSourceRecordLookupName)
                            && SObjectActions.canTakeDefaultGLAVFromSource((Id) newRecord.get(sourceRecordLookupName), accountSourceMap, 3)) {

                        newRecord.put(
                                glav3FieldApiName,
                                accountSourceMap.get((Id) newRecord.get(sourceRecordLookupName)).GL_Account_Variable_3__c
                        );
                    }
                    else if (!productMap.isEmpty()
                            && newRecordFieldMap.containsKey(productFieldFullApiName)
                            && SObjectActions.canTakeDefaultGLAVFromSource((Id) newRecord.get(productFieldFullApiName), productMap, 3)) {

                        newRecord.put(
                                glav3FieldApiName,
                                productMap.get((Id) newRecord.get(productFieldFullApiName)).GL_Account_Variable_3__c
                        );
                    }
                }

                if (newRecord.get(glav4FieldApiName) == NULL) {
                    if (newRecordFieldMap.containsKey(fullyQualifiedSourceRecordLookupName)
                            && SObjectActions.canTakeDefaultGLAVFromSource((Id) newRecord.get(sourceRecordLookupName), accountSourceMap, 4)) {

                        newRecord.put(
                                glav4FieldApiName,
                                accountSourceMap.get((Id) newRecord.get(sourceRecordLookupName)).GL_Account_Variable_4__c
                        );
                    }
                    else if (!productMap.isEmpty()
                            && newRecordFieldMap.containsKey(productFieldFullApiName)
                            && SObjectActions.canTakeDefaultGLAVFromSource((Id) newRecord.get(productFieldFullApiName), productMap, 4)) {

                        newRecord.put(
                                glav4FieldApiName,
                                productMap.get((Id) newRecord.get(productFieldFullApiName)).GL_Account_Variable_4__c
                        );
                    }
                }
            }
        }
    }

    public static String getSourceRecordLookupAPIName(Schema.SObjectType objType) {
        String result;
        if (objType.getDescribe().isCustom()) {
            result = objType.getDescribe().getName();
        }
        else {
            result = objType.getDescribe().getName() + '__c';
        }

        return result;
    }

    public static Map<Id, Account> getAccountSourceMap(Set<Id> sourceRecordIds, Schema.SObjectType objType) {
        Map<Id, Account> result = new Map<Id, Account>();
        List<String> queryFields = new List<String>{'Id'};
        String queryCondition = 'Id IN :sourceRecordIds';
        Map<String, Schema.SObjectType> globalDescribe;
        
        If (IS_ERP_ENABLED) {
            globalDescribe = Schema.getGlobalDescribe();
        }

        if (objType == Billing__c.SObjectType || objType == Recurring_Billing__c.SObjectType) {
            queryFields.add('Customer__c');
            queryFields.add('Customer__r.GL_Account_Variable_1__c');
            queryFields.add('Customer__r.GL_Account_Variable_2__c');
            queryFields.add('Customer__r.GL_Account_Variable_3__c');
            queryFields.add('Customer__r.GL_Account_Variable_4__c');
        }
        else if (objType == Account_Payable__c.SObjectType || objType == Recurring_Account_Payable__c.SObjectType) {
            queryFields.add('Vendor__c');
            queryFields.add('Vendor__r.GL_Account_Variable_1__c');
            queryFields.add('Vendor__r.GL_Account_Variable_2__c');
            queryFields.add('Vendor__r.GL_Account_Variable_3__c');
            queryFields.add('Vendor__r.GL_Account_Variable_4__c');

            queryCondition += ' AND Vendor__c != NULL';
        }
        else if (IS_ERP_ENABLED && objType == globalDescribe.get(ERP_PACKAGE_QUALIFIER + 'Sales_Order__c')) {
            queryFields.add(ERP_PACKAGE_QUALIFIER + 'Customer__c');
            queryFields.add(ERP_PACKAGE_QUALIFIER + 'Customer__r.' + PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c');
            queryFields.add(ERP_PACKAGE_QUALIFIER + 'Customer__r.' + PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c');
            queryFields.add(ERP_PACKAGE_QUALIFIER + 'Customer__r.' + PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c');
            queryFields.add(ERP_PACKAGE_QUALIFIER + 'Customer__r.' + PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c');
        }
        else if (IS_ERP_ENABLED && objType == globalDescribe.get(ERP_PACKAGE_QUALIFIER + 'Purchase_Order__c')) {
            queryFields.add(ERP_PACKAGE_QUALIFIER + 'Vendor__c');
            queryFields.add(ERP_PACKAGE_QUALIFIER + 'Vendor__r.' + PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c');
            queryFields.add(ERP_PACKAGE_QUALIFIER + 'Vendor__r.' + PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c');
            queryFields.add(ERP_PACKAGE_QUALIFIER + 'Vendor__r.' + PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c');
            queryFields.add(ERP_PACKAGE_QUALIFIER + 'Vendor__r.' + PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c');

            queryCondition += ' AND ' + ERP_PACKAGE_QUALIFIER + 'Vendor__c != NULL';
        }
        else if (objType == Account.SObjectType) {
            queryFields.add('GL_Account_Variable_1__c');
            queryFields.add('GL_Account_Variable_2__c');
            queryFields.add('GL_Account_Variable_3__c');
            queryFields.add('GL_Account_Variable_4__c');
        }
        else if (objType == Project__c.SObjectType) {
            queryFields.add('Account__c');
            queryFields.add('Account__r.GL_Account_Variable_1__c');
            queryFields.add('Account__r.GL_Account_Variable_2__c');
            queryFields.add('Account__r.GL_Account_Variable_3__c');
            queryFields.add('Account__r.GL_Account_Variable_4__c');
        }

        SOQLBuilder theQuery = new SOQLBuilder(objType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        for (SObject rec : Database.query(theQuery.toSOQL())) {
            Account accountRecord;
            if (rec.getSObjectType() == Account.SObjectType) {
                accountRecord = (Account) rec;
            }
            else if (rec.getSObjectType() == Billing__c.SObjectType || rec.getSObjectType() == Recurring_Billing__c.SObjectType) {
                accountRecord = (Account) rec.getSObject('Customer__r');
            }
            else if (rec.getSObjectType() == Account_Payable__c.SObjectType || rec.getSObjectType() == Recurring_Account_Payable__c.SObjectType) {
                accountRecord = (Account) rec.getSObject('Vendor__r');
            }
            else if (IS_ERP_ENABLED && objType == globalDescribe.get(ERP_PACKAGE_QUALIFIER + 'Sales_Order__c')) {
                accountRecord = (Account) rec.getSObject(ERP_PACKAGE_QUALIFIER + 'Customer__r');
            }
            else if (IS_ERP_ENABLED && objType == globalDescribe.get(ERP_PACKAGE_QUALIFIER + 'Purchase_Order__c')) {
                accountRecord = (Account) rec.getSObject(ERP_PACKAGE_QUALIFIER + 'Vendor__r');
            }
            else if (rec.getSObjectType() == Project__c.SObjectType) {
                accountRecord = (Account) rec.getSObject('Account__r');
            }
            result.put(rec.Id, accountRecord);
        }

        return result;
    }

    public static Map<Id, Product2> getProductSourceMap(List<SObject> newRecords) {
        Map<Id, Product2> result;

        String productFieldFullApiName = addNamespacePrefixToFieldName('Product__c', newRecords.getSObjectType());

        if (newRecords.getSObjectType().getDescribe().fields.getMap().containsKey(productFieldFullApiName)) {
            Set<Id> productIds = new Set<Id>();
            for (SObject newRecord : newRecords) {
                productIds.add((Id) newRecord.get(productFieldFullApiName));
            }

            result = new Map<Id, Product2>([
                SELECT  Id,
                        GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c,
                        GL_Account_Variable_4__c
                FROM Product2
                WHERE Id IN :productIds
                LIMIT :productIds.size()
            ]);
        }
        else {
            result = new Map<Id, Product2>();
        }
        return result;
    }

    public static void updateLedgerField(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {

        for (SObject newObj : newMap.values()) {
            SObject oldObj = oldMap.get(newObj.Id);
            if (oldObj.get(PACKAGE_QUALIFIER + 'Ledger__c') == NULL && newObj.get(PACKAGE_QUALIFIER + 'Ledger__c') == NULL) {
                newObj.put(PACKAGE_QUALIFIER + 'Ledger__c', LedgerHandler.getLegacyDefaultLedgerId());
            }
        }
    }

    /*
    * This will populate Ledger field with default Ledger record only if it is available for the current user
    * */
    public static void populateLedgerField(List<SObject> newRecords) {
        try {
            Id defaultLedgerId = LedgerHandler.getLedgerIdWithSharing();
            for (SObject record : newRecords) {
                populateLedgerField(record,defaultLedgerId);
            }
        }
        catch (Exception ex) {
            for (SObject record : newRecords) {
                record.addError(ex.getMessage(), false);
            }
        }
    }

    public static void populateLedgerField(SObject record, Id defaultLedgerId) {
        if (record.get('Ledger__c') == NULL) {
            record.put('Ledger__c', defaultLedgerId);
        }
    }

    public static void populateDefaultStatus(List<SObject> newRecords, Boolean isRecordPostable) {
        List<Schema.PicklistEntry> statusPicklistEntries =
            newRecords.getSObjectType().getDescribe().fields.getMap()
            .get(PACKAGE_QUALIFIER + 'Status__c').getDescribe().getPicklistValues();

        Set<String> picklistValues = new Set<String>();
        String defaultVal = 'In Process';

        for (Schema.PicklistEntry pe : statusPicklistEntries) {
            picklistValues.add(pe.getValue());
            if (pe.isDefaultValue()) {
                defaultVal = pe.getValue();
            }
        }
        //add one additional Status value for records which can be posted
        if (isRecordPostable) {
            picklistValues.add('Posted');
        }
        //set default picklist value in case if
        //it has not been set directly
        //or it has been set to some undefined value
        for (SObject record : newRecords) {
            if (record.get(PACKAGE_QUALIFIER + 'Status__c') == NULL
                    || !picklistValues.contains((String) record.get(PACKAGE_QUALIFIER + 'Status__c')) ) {

                record.put(PACKAGE_QUALIFIER + 'Status__c', defaultVal);
            }
        }
    }

    private static Map<SObjectType, SObjectField> ledgerFieldsByObjectTypes = new Map<SObjectType, SObjectField>{
            Billing__c.getSObjectType() => Billing__c.Ledger__c,
            Billing_Line__c.getSObjectType() => Billing_Line__c.Ledger__c,
            Recurring_Billing__c.getSObjectType() => Recurring_Billing__c.Ledger__c,
            Recurring_Billing_Line__c.getSObjectType() => Recurring_Billing_Line__c.Ledger__c,

            Account_Payable__c.getSObjectType() => Account_Payable__c.Ledger__c,
            Account_Payable_Line__c.getSObjectType() => Account_Payable_Line__c.Ledger__c,
            Recurring_Account_Payable__c.getSObjectType() => Recurring_Account_Payable__c.Ledger__c,
            Recurring_Account_Payable_Line__c.getSObjectType() => Recurring_Account_Payable_Line__c.Ledger__c,

            Journal_Entry__c.getSObjectType() => Journal_Entry__c.Ledger__c,
            Journal_Entry_Line__c.getSObjectType() => Journal_Entry_Line__c.Ledger__c,
            Recurring_Journal_Entry__c.getSObjectType() => Recurring_Journal_Entry__c.Ledger__c,
            Recurring_Journal_Entry_Line__c.getSObjectType() => Recurring_Journal_Entry_Line__c.Ledger__c,

            Cash_Receipt__c.getSObjectType() => Cash_Receipt__c.Ledger__c,
            Cash_Disbursement__c.getSObjectType() => Cash_Disbursement__c.Ledger__c,

            Scheduled_Revenue_Expense__c.getSObjectType() => Scheduled_Revenue_Expense__c.Ledger__c,
            Time_Card__c.getSObjectType() => Time_Card__c.Ledger__c,

            Bank_Deposit__c.getSObjectType() => Bank_Deposit__c.Ledger__c,
            Bank_Disbursement__c.getSObjectType() => Bank_Disbursement__c.Ledger__c,
            Bank_Reconciliation2__c.getSObjectType() => Bank_Reconciliation2__c.Ledger__c,
            Expense_Report__c.getSObjectType() => Expense_Report__c.Ledger__c,
            Period_Task__c.getSObjectType() => Period_Task__c.Ledger__c
    };
    public static void lockAccountingMethodChanging(List<SObject> newRecords) {
        SObjectType sObjType = newRecords.getSObjectType();
        sObjType = sObjType != null ? sObjType : newRecords[0].getSObjectType();
        if (sObjType != null) {
            SObjectField ledgerField = ledgerFieldsByObjectTypes.get(sObjType);
            for (SObject record : newRecords) {
                Id ledgerId = (Id) record.get(ledgerField);
                String ledgerAcctMethod = String.isNotBlank(ledgerId)
                        ? LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId).Accounting_Method__c
                        : null;
                String sourceAcctMethod = (String)record.get(PACKAGE_QUALIFIER + 'Accrual_and_or_Cash__c');
                if (String.isNotBlank(ledgerAcctMethod)
                        && String.isNotBlank(sourceAcctMethod)
                        && ledgerAcctMethod != LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH
                        && ledgerAcctMethod != sourceAcctMethod) {
                    String message = String.format(Label.ERR_ONLY_SOURCE_WITH_CORRECT_ACCOUNTING_METHOD, new List<String>{ ledgerAcctMethod });
                    if (Journal_Entry__c.getSObjectType() == sObjType) { ((Journal_Entry__c) record).Accrual_and_or_Cash__c.addError(message); }
                    if (Recurring_Journal_Entry__c.getSObjectType() == sObjType) { ((Recurring_Journal_Entry__c) record).Accrual_and_or_Cash__c.addError(message); }
                    if (Scheduled_Revenue_Expense__c.getSObjectType() == sObjType) { ((Scheduled_Revenue_Expense__c) record).Accrual_and_or_Cash__c.addError(message); }
                }
            }
        }
    }
    public static void preventInactiveLedgers(List<SObject> newRecords) {
        SObjectType sObjType = newRecords.getSObjectType();
        sObjType = sObjType != null ? sObjType : newRecords[0].getSObjectType();
        if (sObjType != null) {
            SObjectField ledgerField = ledgerFieldsByObjectTypes.get(sObjType);
            for (SObject record : newRecords) {
                Id ledgerId = (Id)record.get(ledgerField);
                if (String.isNotBlank(ledgerId) && !LedgerHandler.getInstanceWithoutSharing().isActiveLedger(ledgerId)) {
                    throwLedgerFieldError(sObjType, record, Label.ERR_LEDGER_ACTIVE_ONLY);
                }
            }
        }
    }

    private static final Set<SObjectType> SKIP_SHADOW_ELIMINATION = new Set<SObjectType>{
            Journal_Entry__c.SObjectType,
            Journal_Entry_Line__c.SObjectType,
            Recurring_Journal_Entry__c.SObjectType,
            Recurring_Journal_Entry_Line__c.SObjectType
    };
    public static void preventShadowLedgers(List<SObject> newRecords) {
        SObjectType sObjType = newRecords.getSObjectType();
        sObjType = sObjType != null ? sObjType : newRecords[0].getSObjectType();
        if (sObjType != null) {
            SObjectField ledgerField = ledgerFieldsByObjectTypes.get(sObjType);
            for (SObject record : newRecords) {
                Id ledgerId = (Id)record.get(ledgerField);
                if (String.isNotBlank(ledgerId)
                        && LedgerHandler.getInstanceWithoutSharing().isShadowLedger(ledgerId)
                        && (!SKIP_SHADOW_ELIMINATION.contains(sObjType) || !LedgerHandler.getInstanceWithoutSharing().isEliminationLedgerById(ledgerId))) {
                    throwLedgerFieldError(sObjType, record, Label.ERR_LEDGER_PRIMARY_ONLY);
                }
            }
        }
    }

    private static void throwLedgerFieldError(SObjectType sObjType, SObject record, String errorMessage) {
        if (Billing__c.getSObjectType() == sObjType) { ((Billing__c) record).Ledger__c.addError(errorMessage); }
        if (Billing_Line__c.getSObjectType() == sObjType) { ((Billing_Line__c) record).Ledger__c.addError(errorMessage); }
        if (Recurring_Billing__c.getSObjectType() == sObjType) { ((Recurring_Billing__c) record).Ledger__c.addError(errorMessage); }
        if (Recurring_Billing_Line__c.getSObjectType() == sObjType) { ((Recurring_Billing_Line__c) record).Ledger__c.addError(errorMessage); }

        if (Account_Payable__c.getSObjectType() == sObjType) { ((Account_Payable__c) record).Ledger__c.addError(errorMessage); }
        if (Account_Payable_Line__c.getSObjectType() == sObjType) { ((Account_Payable_Line__c) record).Ledger__c.addError(errorMessage); }
        if (Recurring_Account_Payable__c.getSObjectType() == sObjType) { ((Recurring_Account_Payable__c) record).Ledger__c.addError(errorMessage); }
        if (Recurring_Account_Payable_Line__c.getSObjectType() == sObjType) { ((Recurring_Account_Payable_Line__c) record).Ledger__c.addError(errorMessage); }

        if (Journal_Entry__c.getSObjectType() == sObjType) { ((Journal_Entry__c) record).Ledger__c.addError(errorMessage); }
        if (Journal_Entry_Line__c.getSObjectType() == sObjType) { ((Journal_Entry_Line__c) record).Ledger__c.addError(errorMessage); }
        if (Recurring_Journal_Entry__c.getSObjectType() == sObjType) { ((Recurring_Journal_Entry__c) record).Ledger__c.addError(errorMessage); }
        if (Recurring_Journal_Entry_Line__c.getSObjectType() == sObjType) { ((Recurring_Journal_Entry_Line__c) record).Ledger__c.addError(errorMessage); }

        if (Cash_Receipt__c.getSObjectType() == sObjType) { ((Cash_Receipt__c) record).Ledger__c.addError(errorMessage); }
        if (Cash_Disbursement__c.getSObjectType() == sObjType) { ((Cash_Disbursement__c) record).Ledger__c.addError(errorMessage); }

        if (Scheduled_Revenue_Expense__c.getSObjectType() == sObjType) { ((Scheduled_Revenue_Expense__c) record).Ledger__c.addError(errorMessage); }
        if (Time_Card__c.getSObjectType() == sObjType) { ((Time_Card__c) record).Ledger__c.addError(errorMessage); }

        if (Bank_Deposit__c.getSObjectType() == sObjType) { ((Bank_Deposit__c) record).Ledger__c.addError(errorMessage); }
        if (Bank_Disbursement__c.getSObjectType() == sObjType) { ((Bank_Disbursement__c) record).Ledger__c.addError(errorMessage); }
        if (Bank_Reconciliation2__c.getSObjectType() == sObjType) { ((Bank_Reconciliation2__c) record).Ledger__c.addError(errorMessage); }
        if (Expense_Report__c.getSObjectType() == sObjType) { ((Expense_Report__c) record).Ledger__c.addError(errorMessage); }
        if (Period_Task__c.getSObjectType() == sObjType) { ((Period_Task__c) record).Ledger__c.addError(errorMessage); }
    }

    public static void validateLedgerType(List<SObject> newRecords) {
        validateLedgerType(newRecords, false);
    }

    public static void validateLedgerType(List<SObject> newRecords, Boolean allowElimination) {
        List<Ledger__c> transactionalLedgers = LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers();
        List<Ledger__c> eliminationLedgers =
            (allowElimination)
                ? LedgerHandler.getInstanceWithoutSharing().getEliminationsTransactionalLedgers()
                : new List<Ledger__c>();

        Map<Id, Ledger__c> ledgerMap = new Map<Id, Ledger__c>();
        ledgerMap.putAll(transactionalLedgers);
        ledgerMap.putAll(eliminationLedgers);

        for (SObject record : newRecords) {
            if (record.get('Ledger__c') != NULL && !ledgerMap.containsKey((Id) record.get('Ledger__c'))) {
                record.addError(
                    (allowElimination)
                        ? LEDGER_TYPE_TRANSACTIONAL_AND_ELIMINATION_TRANSACTIONAL_ONLY_ERROR
                        : LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR
                );
            }
        }
    }

    public static Boolean canTakeDefaultGLAVFromSource(Id sourceId, Map<Id, SObject> sourceMap, Integer glavNumber) {
        Boolean result = false;
        if (glavNumber == 1) {
            result = sourceId != NULL
                        && sourceMap.containsKey(sourceId)
                        && sourceMap.get(sourceId)?.get('GL_Account_Variable_1__c') != NULL;
        }

        if (glavNumber == 2) {
            result = sourceId != NULL
                        && sourceMap.containsKey(sourceId)
                        && sourceMap.get(sourceId)?.get('GL_Account_Variable_2__c') != NULL;
        }

        if (glavNumber == 3) {
            result = sourceId != NULL
                        && sourceMap.containsKey(sourceId)
                        && sourceMap.get(sourceId)?.get('GL_Account_Variable_3__c') != NULL;
        }

        if (glavNumber == 4) {
            result = sourceId != NULL
                        && sourceMap.containsKey(sourceId)
                        && sourceMap.get(sourceId)?.get('GL_Account_Variable_4__c') != NULL;
        }
        return result;
    }

    private static String addNamespacePrefixToFieldName(String fieldName, Schema.SObjectType objType) {
        String result = fieldName;
        if (IS_ERP_ENABLED
                && !String.isBlank(ERP_PACKAGE_QUALIFIER)
                && objType.getDescribe().getName().contains(ERP_PACKAGE_QUALIFIER)
                && !fieldName.contains(ERP_PACKAGE_QUALIFIER)) {

            result = ERP_PACKAGE_QUALIFIER + fieldName;
        }
        else if (!String.isBlank(PACKAGE_QUALIFIER) && objType.getDescribe().getName().contains(PACKAGE_QUALIFIER) && !fieldName.contains(PACKAGE_QUALIFIER)) {
            result = PACKAGE_QUALIFIER + fieldName;
        }
        return result;
    }

    public static void normalizeNumericAndCurrencyFields(List<SObject> sourceList, Map<SObjectField, Integer> fieldScaleMap) {
        for (SObject obj : sourceList) {
            for (SObjectField fieldToken : fieldScaleMap.keySet()) {
                if (obj.get(fieldToken) != NULL) {
                    obj.put(fieldToken, ((Decimal) obj.get(fieldToken)).setScale(fieldScaleMap.get(fieldToken), System.RoundingMode.HALF_UP));
                }
            }
        }
    }

    public static void preventOverApply(List<SObject> newLines) {
        for (SObject newObj : newLines) {
            Decimal absApplied = (Decimal) newObj.get(PACKAGE_QUALIFIER + 'Applied_Amount__c');
            Decimal absTotal = (Decimal) newObj.get(PACKAGE_QUALIFIER + 'Amount__c');

            absApplied = absApplied != NULL ? absApplied.setScale(2,System.RoundingMode.HALF_UP) : 0;
            absTotal = absTotal != NULL ? absTotal.setScale(2,System.RoundingMode.HALF_UP) : 0;

            if (Math.abs(absApplied) > Math.abs(absTotal)) {
                newObj.addError(
                    String.format(
                        SObjectActions.OVER_APPLIED_ERROR,
                        new List<String> {newObj.getSObjectType().getDescribe().getLabel()}
                    )
                );
            }
        }
    }

    public static void deleteSourceRecordUpdateBTStatus(List<SObject> deletedRecords) {
        Set<Id> bankTransactionsIds = new Set<Id>();
        for (SObject record : deletedRecords) {
            if (record.get('Bank_Transaction__c') != NULL) {
                bankTransactionsIds.add((Id) record.get('Bank_Transaction__c'));
            }
        }
        BankTransactionsHelper.updateBankTransactionsStatus(
            DomainUtils.getBankTransactionsById(bankTransactionsIds),
            BankTransactionsHelper.BT_UNMATCHED_STATUS
        );
    }

    public static void amountUpdateSourceRecordUpdateBTStatus(List<SObject> newLines, Map<Id, SObject> oldLines, SObjectField unlockedField) {
        Set<Id> bankTransactionsIds = new Set<Id>();

        for (SObject newLine : newLines) {
            SObject oldLine = oldLines.get(newLine.Id);
            if (newLine.get('Bank_Transaction__c') != NULL && newLine.get('Amount__c') != oldLine.get('Amount__c')) {
                bankTransactionsIds.add((Id) newLine.get('Bank_Transaction__c'));
                newLine.put('Cleared_Date__c', NULL);
                newLine.put('Bank_Transaction__c', NULL);
                //unlock Bank Transaction field on CD, CR or JEL
                TriggerObserver.getInstance().unlockField(unlockedField);
            }
        }

        if (!bankTransactionsIds.isEmpty()) {
            asyncBTStatusUpdate(bankTransactionsIds, BankTransactionsHelper.BT_UNMATCHED_STATUS);
        }
    }

    @future
    public static void asyncBTStatusUpdate(Set<Id> bankTransactionsIds, String status) {
        BankTransactionsHelper.updateBankTransactionsStatus(
            DomainUtils.getBankTransactionsById(bankTransactionsIds),
            status
        );
    }

    public static void handleBtForceMatch(List<SObject> newRecords, Map<Id, SObject> oldRecordsMap) {
        //Will work only if Force Match permission is enabled
        if (SourceDocumentUpdateFieldValidator.isForceMatchPermitted()) {
            Set<Id> bankTransactionsToMatchedStatus = new Set<Id>();
            Set<Id> bankTransactionsToUnmatchedStatus = new Set<Id>();
            for (SObject newRecord : newRecords) {
                Id oldBtId = (Id) oldRecordsMap.get(newRecord.Id)?.get('Bank_Transaction__c');
                Id newBtId = (Id) newRecord.get('Bank_Transaction__c');
                if (oldBtId == NULL && newBtId != NULL) {
                    //set
                    bankTransactionsToMatchedStatus.add(newBtId);
                }
                else if (oldBtId != NULL && newBtId == NULL) {
                    //clear
                    bankTransactionsToUnmatchedStatus.add(oldBtId);
                }
                else if (oldBtId != NULL && newBtId != NULL && oldBtId != newBtId) {
                    //replace
                    bankTransactionsToMatchedStatus.add(newBtId);
                    bankTransactionsToUnmatchedStatus.add(oldBtId);
                }
            }
            //Set Status value on Bank Transaction records
            if (!bankTransactionsToMatchedStatus.isEmpty()) {
                BankTransactionsHelper.updateBankTransactionsStatus(
                    bankTransactionsToMatchedStatus, BankTransactionsHelper.BT_MATCHED_STATUS
                );
            }
            if (!bankTransactionsToUnmatchedStatus.isEmpty()) {
                BankTransactionsHelper.updateBankTransactionsStatus(
                    bankTransactionsToUnmatchedStatus, BankTransactionsHelper.BT_UNMATCHED_STATUS
                );
            }
        }
    }

    public static void validateAppliedDateIsInAppliedAccountingPeriod(List<SObject> creditMemos) {
        try {
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            for (SObject creditMemo : creditMemos) {
                Date appliedDate = (Date) creditMemo.get('Applied_Date__c');
                Id appliedPeriodId = (Id) creditMemo.get('Accounting_Period__c');


                if (appliedDate != NULL
                        && appliedPeriodId != NULL
                        && !acctPeriodHandler.isDateWithinTheAccountingPeriod(appliedDate, appliedPeriodId)) {

                    creditMemo.addError(APPLIED_DATE_OUTSIDE_ACCOUNTING_PERIOD_ERROR);
                }
            }
        }
        catch (Exception ex) {
            for (SObject creditMemo : creditMemos) {
                creditMemo.addError(ex.getMessage());
            }
        }
    }

    public static Map<Id, Id> ledgerIdBySourceId(List<SObject> sourceRecords) {
        Map<Id, Id> result = new Map<Id, Id>();
        if (!sourceRecords.isEmpty()) {
            switch on sourceRecords[0] {
                when AP_Disbursement__c objRecord {
                    for (AP_Disbursement__c record : (List<AP_Disbursement__c>) sourceRecords) {
                        result.put(record.Id, record.Cash_Disbursement__r.Ledger__c);
                    }
                }
                when Billing_Cash_Receipt__c objRecord {
                    for (Billing_Cash_Receipt__c record : (List<Billing_Cash_Receipt__c>) sourceRecords) {
                        result.put(record.Id, record.Cash_Receipt__r.Ledger__c);
                    }
                }
                when Journal_Entry_Line__c objRecord {
                    for (Journal_Entry_Line__c record : (List<Journal_Entry_Line__c>) sourceRecords) {
                        result.put(record.Id, record.Journal_Entry__r.Ledger__c);
                    }
                }
                when Recurring_Journal_Entry_Line__c objRecord {
                    for (Recurring_Journal_Entry_Line__c record : (List<Recurring_Journal_Entry_Line__c>) sourceRecords) {
                        result.put(record.Id, record.Recurring_Journal_Entry__r.Ledger__c);
                    }
                }
                when else {
                    for (SObject record : sourceRecords) {
                        result.put(record.Id, (Id) record.get(PACKAGE_QUALIFIER + 'Ledger__c'));
                    }
                }
            }
        }
        return result;
    }

    public static Boolean isPostedStatus(SObject record) {
        return (String) record.get(PACKAGE_QUALIFIER + 'Status__c') == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
            || (String) record.get(PACKAGE_QUALIFIER + 'Status__c') == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS
            || (String) record.get(PACKAGE_QUALIFIER + 'Status__c') == AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS;
    }

    public static void preventUpdateFieldWithAssociatedRecordsOnBankDisb(Map<Id, SObject> oldBankDisbursementsMap, Map<Id, SObject> newBankDisbursementsMap, String fieldName) {
        Boolean isSystemLedgerUpdated;
        if (fieldName == 'CurrencyIsoCode' && !MultiCurrencyHandler.isMultiCurrencyEnabled) {
            return;
        }
        Set<Id> bankDisbIds = new Set<Id>();
        for (Id bdId : newBankDisbursementsMap.keySet()) {
            isSystemLedgerUpdated = false;
            if (fieldName == 'Ledger__c'
                && oldBankDisbursementsMap.get(bdId).get(fieldName) == NULL
                && newBankDisbursementsMap.get(bdId).get(fieldName) == LedgerHandler.getLegacyDefaultLedgerId()) {
                isSystemLedgerUpdated = true;
            }
            if (newBankDisbursementsMap.get(bdId).get(fieldName) != oldBankDisbursementsMap.get(bdId).get(fieldName) && !isSystemLedgerUpdated) {
                bankDisbIds.add(bdId);
            }
        }
        if (!bankDisbIds.isEmpty()) {
            Schema.SObjectType sObjectType = newBankDisbursementsMap.getSObjectType();
            List<SObject> bankDisbChildRecords = new List<SObject>();
            if (sObjectType == Bank_Disbursement__c.getSObjectType()) {
                bankDisbChildRecords = DomainUtils.getBankDisbursementById(bankDisbIds);
            }

            for (SObject bd : bankDisbChildRecords) {
                if (((bd.getSObjects('Cash_Disbursements__r') != NULL) && !((List<SObject>) bd.getSObjects('Cash_Disbursements__r')).isEmpty()) ||
                        ((bd.getSObjects('Journal_Entry_Lines__r') != NULL) && !((List<SObject>) bd.getSObjects('Journal_Entry_Lines__r')).isEmpty())) {

                    newBankDisbursementsMap.get(bd.Id).addError(
                            String.format(
                                    FIELD_CHANGE_WITH_ASSOCIATED_RECORD_ERROR_MAP.get(sObjectType),
                                    new List<String> {sObjectType.getDescribe().fields.getMap().get(PACKAGE_QUALIFIER + fieldName).getDescribe().getLabel()}
                            ), false);
                }
            }
        }
    }
    
    public static Boolean isLDOInProgressStatus(Sobject obj) {
        return (String) obj.get(PACKAGE_QUALIFIER + 'Status__c') == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS
            || (String) obj.get(PACKAGE_QUALIFIER + 'Status__c') == AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS;
    }

}