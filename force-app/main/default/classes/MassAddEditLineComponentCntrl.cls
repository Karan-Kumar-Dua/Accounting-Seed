public with sharing class MassAddEditLineComponentCntrl {

    public static final String VALIDATION_ERROR = Label.ERR_VALIDATION;

    private static final String FS_PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;

    private static final String ENTRY_TYPE_AP_LINE = FS_PACKAGE_QUALIFIER + 'Account_Payable_Line__c';
    private static final String ENTRY_TYPE_BILLING_LINE = FS_PACKAGE_QUALIFIER + 'Billing_Line__c';
    private static final String ENTRY_TYPE_JOURNAL_ENTRY_LINE = FS_PACKAGE_QUALIFIER + 'Journal_Entry_Line__c';
    private static final String ENTRY_TYPE_SALES_ORDER_LINE = ERP_PACKAGE_QUALIFIER + 'Sales_Order_Line__c';
    private static final String ENTRY_TYPE_PURCHASE_ORDER_LINE = ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Line__c';
    private static final String ENTRY_TYPE_AP = FS_PACKAGE_QUALIFIER + 'Account_Payable__c';
    private static final String ENTRY_TYPE_BILLING = FS_PACKAGE_QUALIFIER + 'Billing__c';
    private static final String ENTRY_TYPE_JOURNAL_ENTRY = FS_PACKAGE_QUALIFIER + 'Journal_Entry__c';
    private static final String ENTRY_TYPE_SALES_ORDER = ERP_PACKAGE_QUALIFIER + 'Sales_Order__c';
    private static final String ENTRY_TYPE_PURCHASE_ORDER = ERP_PACKAGE_QUALIFIER + 'Purchase_Order__c';

    private static Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

    private static Map<String, List<String>> requiredFieldsByApiName = new Map<String, List<String>>{
        ENTRY_TYPE_BILLING => new List<String>{
            FS_PACKAGE_QUALIFIER + 'Billing_Cash_Receipt_Count__c',
            FS_PACKAGE_QUALIFIER + 'Credit_Memo_Applied_Amount__c',
            FS_PACKAGE_QUALIFIER + 'Ledger__c'
        },
        ENTRY_TYPE_PURCHASE_ORDER => new List<String>{ERP_PACKAGE_QUALIFIER + 'Vendor__c'},
        ENTRY_TYPE_AP => new List<String>{FS_PACKAGE_QUALIFIER + 'Ledger__c'}
    };

    private static Map<String, Set<String>> readonlyFieldsByApiName = new Map<String, Set<String>>{
        ENTRY_TYPE_AP_LINE => new Set<String>{FS_PACKAGE_QUALIFIER + 'Amount__c', FS_PACKAGE_QUALIFIER + 'Tax_Amount__c'},
        ENTRY_TYPE_BILLING_LINE => new Set<String>{FS_PACKAGE_QUALIFIER + 'Tax_Amount2__c'}
    };

    @TestVisible
    private static Set<SObjectField> requiredFieldsForAvalara = new Set<SObjectField>{
        Billing_Line__c.Hours_Units__c,
        Billing_Line__c.Rate__c,
        Billing_Line__c.Product__c
    };

    private static String requiredFieldsForAvalaraToString() {
        List<String> fieldLabels = new List<String>();
        for (SObjectField field : requiredFieldsForAvalara) {
            fieldLabels.add(field.getDescribe().getLabel());
        }
        return String.join(fieldLabels, ',');
    }

    public static final String AVALARA_BILLING_LINE_FIELD_SET_VALIDATION_ERROR =
        Label.INF_FOLLOWING_FIELDS_REQUIRE_MASSADDEDITROWS_BILLING_LINE + requiredFieldsForAvalaraToString();

    public Boolean IS_MULTI_CURRENCY_ENABLED { get; set; }
    public Boolean isAvalaraTaxCalcEnabled { get; set; }
    public Boolean isHeaderLevelPostEnabled { get; set; }
    public Integer indexOfRowToDelete { get; set; }
    public Integer recLimit { get; set; }
    public Integer offset { get; set; }
    public Integer recordSetSize { get; set; }
    public Boolean isRecordPosted { get; set; }
    public Boolean isError { get; set; }
    public String currencyIsoCode { get; set; }
    public Boolean isShowPostButton {
        get {
            if (isShowPostButton == NULL && masterRecord != NULL) {
                if (masterRecord.getSobjectType() == globalDescribe.get(ENTRY_TYPE_AP)
                        || masterRecord.getSobjectType() == globalDescribe.get(ENTRY_TYPE_BILLING)
                        || masterRecord.getSobjectType() == globalDescribe.get(ENTRY_TYPE_JOURNAL_ENTRY)) {

                    isShowPostButton = true;
                } else {
                    isShowPostButton = false;
                }
            }
            return isShowPostButton;
        }
        set;
    }
    public with sharing class MassAddEditLineCustomFieldValidationException extends Exception {}

    public Boolean isDetailFieldSetEmpty {
        get {
            return wrappedDetailFields.isEmpty();
        }
    }

    public List<FieldWrapper> wrappedDetailFields {
        get {
            if (wrappedDetailFields == NULL) {
                wrappedDetailFields = wrapDetailFields();
            }
            return wrappedDetailFields;
        }
        set;
    }

    public Boolean isMasterFieldSetEmpty {
        get {
            return wrappedMasterFields.isEmpty();
        }
    }

    public List<FieldWrapper> wrappedMasterFields {
        get {
            if (wrappedMasterFields == NULL) {
                wrappedMasterFields = wrapMasterFields();
            }
            return wrappedMasterFields;
        }
        set;
    }

    private List<String> allDetailFieldPaths;
    private Map <Integer, LineWrapper> allLinesMap;
    @TestVisible
    private List <LineWrapper> removedRows;
    private Integer rowIndex;

    public List <LineWrapper> allLines {
        get {
            if (allLines == NULL) {
                initAllLines();
            }
            return allLines;
        }
        set;
    }

    public SObject masterRecord {
        get;
        set {
            if (masterRecord != NULL && value == NULL) {
                masterRecord = value;
            }
            else if (masterRecord == NULL) {
                masterRecord = value;
                masterRecord = initMasterRecord(value);
            }
            setAvalaraCalcTax(masterRecord);
        }
    }

    private static SObject masterRecordForTax;

    private void setAvalaraCalcTax(SObject masterRecord) {
        isAvalaraTaxCalcEnabled =
                masterRecord != null
                && (new Set<SObjectType>{
                        globalDescribe.get(ENTRY_TYPE_AP),
                        globalDescribe.get(ENTRY_TYPE_BILLING),
                        globalDescribe.get(ENTRY_TYPE_JOURNAL_ENTRY)}
                ).contains(masterRecord.getSObjectType())
                && masterRecord.isSet(FS_PACKAGE_QUALIFIER + 'Ledger__c')
            ? AvaTaxHelper.isAvalaraTaxCalculationEnabled(masterRecord) : false;
        masterRecordForTax = masterRecord != null ? masterRecord : masterRecordForTax;
    }

    public with sharing class LineWrapper {
        public Integer rowIndex { get; set; }
        public SObject rowContentObj { get; set; }
        public List < MassAddEditLineComponentCntrl.FieldWrapper > wrappedFields { get; set; }
        public Map < String, Boolean > errorMap { get; set; }
        public Boolean isAvalaraSalesTax {get; set;}

        public LineWrapper(Integer rowIndex, SObject rowContentObj, List < MassAddEditLineComponentCntrl.FieldWrapper > fieldWrappers) {
            this.rowIndex = rowIndex;
            this.rowContentObj = rowContentObj;
            this.wrappedFields = fieldWrappers;
            this.errorMap = initErrorMap();
            Boolean isAvalaraTaxCalcEnabled = AvaTaxHelper.isAvalaraTaxCalculationEnabled(masterRecordForTax);
            Boolean isHlpMode = AccountingSettingsHandler.isHeaderLevelPost();
            this.isAvalaraSalesTax =
                isAvalaraTaxCalcEnabled
                    && !isHlpMode
                    && rowContentObj.getSObjectType() == globalDescribe.get(ENTRY_TYPE_BILLING_LINE)
                    && rowContentObj.getPopulatedFieldsAsMap().containsKey(FS_PACKAGE_QUALIFIER + 'Product__c')
                    && (Id) rowContentObj.get(FS_PACKAGE_QUALIFIER + 'Product__c') == AvaTaxHelper.getSalesTaxProductId(masterRecordForTax);
        }

        private Map < String, Boolean > initErrorMap() {
            Map < String, Boolean > result = new Map < String, Boolean > ();
            for (MassAddEditLineComponentCntrl.FieldWrapper wrappedField : wrappedFields) {
                result.put(wrappedField.field.getFieldPath(), false);
            }
            return result;
        }
    }

    public with sharing class FieldWrapper {
        public Schema.FieldSetMember field { get; set; }
        public Boolean isRequired { get; set; }
        public Boolean isCurrency { get; set; }
        public Boolean isReadOnly { get; set; }
        public Boolean actionSupport { get; set; }
        public Boolean isLockedDown { get; set; }
        public String helpText { get; set; }

        public FieldWrapper(Schema.FieldSetMember fieldSetMember) {
            this.field = fieldSetMember;
            this.isRequired = checkForRequired();
            this.isCurrency = checkForCurrency();
            this.actionSupport = false;
            this.helpText = getNeedCustomOutput() ? fieldSetMember.getSObjectField().getDescribe().getInlineHelpText() : '';
        }

        public FieldWrapper(Schema.FieldSetMember fieldSetMember, String sObjectAPIName) {
            this(fieldSetMember);
            this.isReadOnly = checkForReadOnly(sObjectAPIName);
            this.isLockedDown = checkForLockedDown(sObjectAPIName);
        }

        private Boolean checkForLockedDown(String sObjectAPIName) {
            Boolean result = false;
            Boolean isAvalaraTaxCalcEnabled = AvaTaxHelper.isAvalaraTaxCalculationEnabled(masterRecordForTax);
            Boolean isHlpMode = AccountingSettingsHandler.isHeaderLevelPost();

            if (isAvalaraTaxCalcEnabled && !isHlpMode && globalDescribe.get(sObjectAPIName) == Billing_Line__c.SObjectType) {
                if (field.getFieldPath() == Billing_Line__c.fields.Product__c.getDescribe().Name
                        || field.getFieldPath() == Billing_Line__c.fields.Hours_Units__c.getDescribe().Name
                        || field.getFieldPath() == Billing_Line__c.fields.Rate__c.getDescribe().Name
                        || field.getFieldPath() == Billing_Line__c.fields.Revenue_GL_Account__c.getDescribe().Name) {

                    result = true;
                }
            }
            return result;
        }

        private Boolean checkForReadOnly(String sObjectAPIName) {
            Boolean result = true;

            if (!isInReadonlyMap(sObjectAPIName) && globalDescribe.get(sObjectAPIName)
                    .getDescribe()
                    .fields
                    .getMap().containsKey(field.getFieldPath())) {

                result = globalDescribe.get(sObjectAPIName)
                    .getDescribe()
                    .fields
                    .getMap()
                    .get(field.getFieldPath())
                    .getDescribe()
                    .isCalculated();
            }

            return result;
        }

        private Boolean isInReadonlyMap(String sObjectAPIName) {
            return readonlyFieldsByApiName.containsKey(sObjectAPIName) && readonlyFieldsByApiName.get(sObjectAPIName).contains(field.getFieldPath());
        }

        private Boolean checkForRequired() {
            return this.field.getDbRequired() || this.field.getRequired();
        }

        private Boolean checkForCurrency() {
            return this.field.getType() == Schema.DisplayType.CURRENCY;
        }

        public Boolean getNeedCustomOutput() {
            if (isReadOnly == NULL) {
                isReadOnly = true;
            }
            return isCurrency && isReadOnly && MultiCurrencyHandler.isMultiCurrencyEnabled;
        }
    }

    public MassAddEditLineComponentCntrl() {
        IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;
        isHeaderLevelPostEnabled = AccountingSettingsHandler.isHeaderLevelPost();
        isError = false;
        offset = offset == NULL ? 0 : offset;
        recLimit = recLimit == NULL ? 10 : recLimit;
        removedRows = new List < MassAddEditLineComponentCntrl.LineWrapper > ();
    }

    private SObject initMasterRecord(SObject value) {
        SObject result;
        try {
            //============================================================================
            // Prepare SOQL Query to query configuration and display information. Since at this point,
            // user MUST have access to master object since bound to custom button on master record detail page.
            // FLS is not handles as all queried fields are bound to output fields on VF Page.
            //============================================================================
            String masterRecordIdValue = (String) value.get('Id');

            Set<String> fields = new Set<String>{'Id', 'Name'};
            for (Schema.FieldSetMember f: this.getMasterFields()) {
                fields.add(f.getFieldPath());
            }
            if (requiredFieldsByApiName.containsKey(getCurrentEntryTypeApiName())) {
                fields.addAll(getRequiredFieldByApiName(getCurrentEntryTypeApiName()));
            }
            if (IS_MULTI_CURRENCY_ENABLED) {
                fields.add('CurrencyIsoCode');
            }
            String query = String.format('SELECT {0} FROM {1} WHERE Id = :masterRecordIdValue', new List<String>{
                    String.join(new List<String>(fields), ','),
                    getCurrentEntryTypeApiName()
            });
            result = Database.query(query)[0];
            if (IS_MULTI_CURRENCY_ENABLED) {
                currencyIsoCode = (String) result.get('CurrencyIsoCode');
            }
        }
        catch (Exception ex) {
            result = createNewEntrySObject();
        }
        return result;
    }

    private Set<String> getRequiredFieldByApiName(String currentApiName) {
        Set<String> fields = new Set<String>();
        for (String field : requiredFieldsByApiName.get(currentApiName)) {
            fields.add(field);
        }
        return fields;
    }

    public String getEntryName() {
        String result;
        if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_AP)) {
            result = Label.COMMON_PAYABLE;
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_BILLING)) {
            result = Label.COMMON_BILLING;
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_JOURNAL_ENTRY)) {
            result = Label.COMMON_JOURNAL_ENTRY;
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_SALES_ORDER)) {
            result = Label.COMMON_SALES_ORDER;
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_PURCHASE_ORDER)) {
            result = Label.COMMON_PURCHASE_ORDER;
        }

        return result;
    }

    public String getEntryAPIName() {
        String entryAPIName = NULL;
        if (masterRecord != NULL) {
            entryAPIName = masterRecord.getSObjectType().getDescribe().getName();
        }
        return entryAPIName;
    }

    private void refreshDataInMasterRecord() {
        try {
            SObject newValue = createNewEntrySObject();
            newValue.put('Id', masterRecord.Id);
            masterRecord = NULL;
            masterRecord = newValue;
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ex.getMessage()));
            throw ex;
        }
    }

    public List<Schema.FieldSetMember> getDetailFields() {
        List<Schema.FieldSetMember> result = new List<Schema.FieldSetMember>();
        String currentEntryLineType = getCurrentEntryLineTypeApiName();

        if (currentEntryLineType == ENTRY_TYPE_AP_LINE) {
            result =
                globalDescribe.get(
                    ENTRY_TYPE_AP_LINE).getDescribe().fieldSets.getMap().get(FS_PACKAGE_QUALIFIER + 'MassAddEditRows'
                ).getFields();
        }
        if (currentEntryLineType == ENTRY_TYPE_BILLING_LINE) {
            result =
                globalDescribe.get(
                    ENTRY_TYPE_BILLING_LINE).getDescribe().fieldSets.getMap().get(FS_PACKAGE_QUALIFIER + 'MassAddEditRows'
                ).getFields();
        }
        if (currentEntryLineType == ENTRY_TYPE_JOURNAL_ENTRY_LINE) {
            result =
                globalDescribe.get(
                    ENTRY_TYPE_JOURNAL_ENTRY_LINE).getDescribe().fieldSets.getMap().get(FS_PACKAGE_QUALIFIER + 'MassAddEditRows'
                ).getFields();
        }
        if (currentEntryLineType == ENTRY_TYPE_SALES_ORDER_LINE) {
            result =
                globalDescribe.get(
                    ENTRY_TYPE_SALES_ORDER_LINE).getDescribe().fieldSets.getMap().get(ERP_PACKAGE_QUALIFIER + 'MassAddEditRows'
                ).getFields();
        }
        if (currentEntryLineType == ENTRY_TYPE_PURCHASE_ORDER_LINE) {
            result =
                globalDescribe.get(
                    ENTRY_TYPE_PURCHASE_ORDER_LINE).getDescribe().fieldSets.getMap().get(ERP_PACKAGE_QUALIFIER + 'MassAddEditRows'
                ).getFields();
        }

        return result;
    }

    public List < FieldWrapper > wrapDetailFields() {
        List < FieldWrapper > result = new List < FieldWrapper > ();
        for (Schema.FieldSetMember fsm : getDetailFields()) {
            FieldWrapper tempFieldWrapper = new FieldWrapper(fsm, getCurrentEntryLineTypeApiName());
            result.add(tempFieldWrapper);
        }

        return result;
    }

    public List < FieldWrapper > wrapMasterFields() {
        List < FieldWrapper > result = new List < FieldWrapper > ();
        for (Schema.FieldSetMember fsm : getMasterFields()) {
            FieldWrapper tempFieldWrapper = new FieldWrapper(fsm);
            result.add(tempFieldWrapper);
        }

        return result;
    }

    public List<Schema.FieldSetMember> getMasterFields() {
        List<Schema.FieldSetMember> result = new List<Schema.FieldSetMember>();
        String currentEntryType = getCurrentEntryTypeApiName();

        if (currentEntryType == ENTRY_TYPE_AP) {
            result = globalDescribe.get(ENTRY_TYPE_AP).getDescribe().fieldSets.getMap().get(FS_PACKAGE_QUALIFIER + 'MassAddEditRows').getFields();
        }
        if (currentEntryType == ENTRY_TYPE_BILLING) {
            result = globalDescribe.get(ENTRY_TYPE_BILLING).getDescribe().fieldSets.getMap().get(FS_PACKAGE_QUALIFIER + 'MassAddEditRows').getFields();
        }
        if (currentEntryType == ENTRY_TYPE_JOURNAL_ENTRY) {
            result = globalDescribe.get(ENTRY_TYPE_JOURNAL_ENTRY).getDescribe().fieldSets.getMap().get(FS_PACKAGE_QUALIFIER + 'MassAddEditRows').getFields();
        }
        if (currentEntryType == ENTRY_TYPE_SALES_ORDER) {
            result = globalDescribe.get(ENTRY_TYPE_SALES_ORDER).getDescribe().fieldSets.getMap().get(ERP_PACKAGE_QUALIFIER + 'MassAddEditRows').getFields();
        }
        if (currentEntryType == ENTRY_TYPE_PURCHASE_ORDER) {
            result = globalDescribe.get(ENTRY_TYPE_PURCHASE_ORDER).getDescribe().fieldSets.getMap().get(ERP_PACKAGE_QUALIFIER + 'MassAddEditRows').getFields();
        }
        return result;
    }

    private String getCurrentEntryLineTypeApiName() {
        String result;
        if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_AP)) {
            result = ENTRY_TYPE_AP_LINE;
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_BILLING)) {
            result = ENTRY_TYPE_BILLING_LINE;
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_JOURNAL_ENTRY)) {
            result = ENTRY_TYPE_JOURNAL_ENTRY_LINE;
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_SALES_ORDER)) {
            result = ENTRY_TYPE_SALES_ORDER_LINE;
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_PURCHASE_ORDER)) {
            result = ENTRY_TYPE_PURCHASE_ORDER_LINE;
        }
        return result;
    }

    private String getCurrentEntryTypeApiName() {
        String result;
        if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_AP)) {
            result = ENTRY_TYPE_AP;
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_BILLING)) {
            result = ENTRY_TYPE_BILLING;
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_JOURNAL_ENTRY)) {
            result = ENTRY_TYPE_JOURNAL_ENTRY;
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_SALES_ORDER)) {
            result = ENTRY_TYPE_SALES_ORDER;
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_PURCHASE_ORDER)) {
            result = ENTRY_TYPE_PURCHASE_ORDER;
        }
        return result;
    }

    private SObject createNewEntryLineSObject() {
        SObject result;
        if (masterRecord.getSobjectType() == globalDescribe.get(ENTRY_TYPE_AP)) {
            result  = globalDescribe.get(ENTRY_TYPE_AP_LINE).newSObject();
            //Bind with master record
            result.put(ENTRY_TYPE_AP, masterRecord.Id);
            result.put(FS_PACKAGE_QUALIFIER + 'Date__c', autoPopulateDate((Date)masterRecord.get(FS_PACKAGE_QUALIFIER + 'Date__c')));

            AccountPayableLineActions.associateDefaultExpenseGLAccount(new List<Account_Payable_Line__c> {
                (Account_Payable_Line__c) result
            });
            //Pre-populate GLAVs
            if (isGLAVsDisplayedOnLine(FS_PACKAGE_QUALIFIER)) {
                SObjectActions.populateGLAVsFromAccountOrProduct(new List<Account_Payable_Line__c> {
                    (Account_Payable_Line__c) result
                });
            }
        }
        else if (masterRecord.getSobjectType() == globalDescribe.get(ENTRY_TYPE_BILLING)) {
            result = globalDescribe.get(ENTRY_TYPE_BILLING_LINE).newSObject();
            //Bind with master record
            result.put(ENTRY_TYPE_BILLING, masterRecord.Id);
            result.put(FS_PACKAGE_QUALIFIER + 'Date__c', autoPopulateDate((Date)masterRecord.get(FS_PACKAGE_QUALIFIER + 'Date__c')));

            BillingLineActions.associateDefaultGLAccounts(new List<Billing_Line__c>{
                (Billing_Line__c) result
            });
            //Pre-populate GLAVs
            if (isGLAVsDisplayedOnLine(FS_PACKAGE_QUALIFIER)) {
                SObjectActions.populateGLAVsFromAccountOrProduct(new List<Billing_Line__c>{
                    (Billing_Line__c) result
                });
            }
        }
        else if (masterRecord.getSobjectType() == globalDescribe.get(ENTRY_TYPE_JOURNAL_ENTRY)) {
            result = globalDescribe.get(ENTRY_TYPE_JOURNAL_ENTRY_LINE).newSObject();
            //Bind with master record
            result.put(ENTRY_TYPE_JOURNAL_ENTRY, masterRecord.Id);
            result.put(FS_PACKAGE_QUALIFIER + 'Date__c', autoPopulateDate((Date)masterRecord.get(FS_PACKAGE_QUALIFIER + 'Journal_Date__c')));
            //Pre-populate GLAVs
            if (isGLAVsDisplayedOnLine(FS_PACKAGE_QUALIFIER)) {
                SObjectActions.populateGLAVsFromAccountOrProduct(new List<Journal_Entry_Line__c>{
                    (Journal_Entry_Line__c) result
                });
            }
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_SALES_ORDER)) {
            result = globalDescribe.get(ENTRY_TYPE_SALES_ORDER_LINE).newSObject();
            //Bind with master record
            result.put(ENTRY_TYPE_SALES_ORDER, masterRecord.Id);
            //Pre-populate GLAVs
            if (isGLAVsDisplayedOnLine(ERP_PACKAGE_QUALIFIER)) {
                SObject[] sObjectList = (SObject[]) Type.forName('List<' + ENTRY_TYPE_SALES_ORDER_LINE + '>').newInstance();
                sObjectList.add(result);                
                SObjectActions.populateGLAVsFromAccountOrProduct(sObjectList);
            }
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_PURCHASE_ORDER)) {
            result = globalDescribe.get(ENTRY_TYPE_PURCHASE_ORDER_LINE).newSObject();
            //Bind with master record
            result.put(ENTRY_TYPE_PURCHASE_ORDER, masterRecord.Id);
            //Pre-populate GLAVs
            if (isGLAVsDisplayedOnLine(ERP_PACKAGE_QUALIFIER)) {
                SObject[] sObjectList = (SObject[]) Type.forName('List<' + ENTRY_TYPE_PURCHASE_ORDER_LINE + '>').newInstance();
                sObjectList.add(result);
                SObjectActions.populateGLAVsFromAccountOrProduct(sObjectList);
            }
        }
        return result;
    }

    private Date autoPopulateDate(Date defaultDate) {
        Date result;
        Set<String> allFieldsInFieldSet = new Set<String>();
        if (allDetailFieldPaths == NULL) {
            for (Schema.FieldSetMember eachFieldSetMember : getDetailFields()) {
                allFieldsInFieldSet.add(eachFieldSetMember.getFieldPath());
            }
            allDetailFieldPaths = new List<String>(allFieldsInFieldSet);
        }
        else {
            allFieldsInFieldSet.addAll(allDetailFieldPaths);
        }

        if (allFieldsInFieldSet.contains(FS_PACKAGE_QUALIFIER + 'Date__c')) {
            result = defaultDate != null ? defaultDate : Date.today();
        }
        return result;
    }

    private Boolean isGLAVsDisplayedOnLine(String currentQualifier) {
        Boolean result = false;
        Set<String> allFieldsInFieldSet = new Set<String>();
        if (allDetailFieldPaths == NULL) {
            for (Schema.FieldSetMember eachFieldSetMember : getDetailFields()) {
                allFieldsInFieldSet.add(eachFieldSetMember.getFieldPath());
            }
            allDetailFieldPaths = new List<String>(allFieldsInFieldSet);
        }
        else {
            allFieldsInFieldSet.addAll(allDetailFieldPaths);
        }

        if (allFieldsInFieldSet.contains(currentQualifier + 'GL_Account_Variable_1__c')
                || allFieldsInFieldSet.contains(currentQualifier + 'GL_Account_Variable_2__c')
                || allFieldsInFieldSet.contains(currentQualifier + 'GL_Account_Variable_3__c')
                || allFieldsInFieldSet.contains(currentQualifier + 'GL_Account_Variable_4__c')) {

            result = true;
        }

        return result;
    }

    private SObject createNewEntrySObject() {
        return masterRecord.getSObjectType().newSObject();
    }

    public PageReference putNewLine() {
        SObject line = createNewEntryLineSObject();
        putNewLine(line);
        return NULL;
    }

    public void putNewLine(SObject line) {
        rowIndex++;
        setActionSupport(line);
        LineWrapper wrappedLine = new LineWrapper(rowIndex, line, wrappedDetailFields);
        allLinesMap.put(rowIndex, wrappedLine);
        allLines = allLinesMap.values();
    }

    private void setActionSupport(SObject line) {
        if (line.getSObjectType() == globalDescribe.get(ENTRY_TYPE_BILLING_LINE)) {
            setActionSupportByFieldName(FS_PACKAGE_QUALIFIER + 'Product__c');
        } else if (line.getSObjectType() == globalDescribe.get(ENTRY_TYPE_AP_LINE)) {
            setActionSupportByFieldName(FS_PACKAGE_QUALIFIER + 'Product__c');
        } else if (line.getSObjectType() == globalDescribe.get(ENTRY_TYPE_PURCHASE_ORDER_LINE)) {
            setActionSupportByFieldName(ERP_PACKAGE_QUALIFIER + 'Product__c');
        }
    }

    private void setActionSupportByFieldName(String fieldNameWithQualifier) {
        for (FieldWrapper fieldWrapper : wrappedDetailFields) {
            if (fieldWrapper.field.getFieldPath() == fieldNameWithQualifier) {
                fieldWrapper.actionSupport = true;
            }
        }
    }

    private Map<Id, SObject> getPPByProductAndMasterRecord(Set<Id> productIds, SObject masterRecord) {
        Map<Id, SObject> result = new Map<Id, SObject>();
        Map<String, SObject> ppMap = getPriceByProductIds(productIds);

        String masterKey = '';
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            masterKey += (String) masterRecord.get('CurrencyIsoCode');
        }
        String fullMasterKey = masterKey + String.valueOf(masterRecord.get(ERP_PACKAGE_QUALIFIER + 'Vendor__c'));

        for (Id productId : productIds) {
            fullMasterKey += String.valueOf(productId);
            masterKey += String.valueOf(productId);

            if (!result.containsKey(productId) && ppMap.containsKey(fullMasterKey)) {
                result.put(productId, ppMap.get(fullMasterKey));
            }
            else if (!result.containsKey(productId) && ppMap.containsKey(masterKey)) {
                result.put(productId, ppMap.get(masterKey));
            }
        }

        return result;
    }

    @TestVisible
    private Map<String, SObject> getPriceByProductIds(Set<Id> productIds) {

        Map<String, SObject> result = new Map<String, SObject>();
        List<SObject> sObjects;
        if(AccountingSettingsHandler.isInventoryValuationAverageCost()){
            sObjects = DomainUtils.getPurchasePriceByProduct(productIds);
        } else {
            sObjects = DomainUtils.getUnitPriceOfProduct(productIds);
        }
        for (SObject ppt : DomainUtils.getPurchasePriceByProduct(productIds)) {
            String key = '';
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                key += (String) ppt.get('CurrencyIsoCode');
            }
            key += ppt.get(ERP_PACKAGE_QUALIFIER + 'Vendor__c') != NULL ? (String) ppt.get(ERP_PACKAGE_QUALIFIER + 'Vendor__c') : '';
            key += String.valueOf((Id) ppt.get(ERP_PACKAGE_QUALIFIER + 'Product__c'));

            if (!result.containsKey(key)) {
                result.put(key, ppt);
            }
        }

        return result;
    }

    public PageReference refreshLines() {
         if (masterRecord.getSobjectType() == globalDescribe.get(ENTRY_TYPE_BILLING)) {
             for (LineWrapper wrapper : allLinesMap.values()) {
                 if (wrapper.rowContentObj.getSObjectType() == globalDescribe.get(ENTRY_TYPE_BILLING_LINE)) {
                     if (wrapper.rowContentObj.Id == NULL) {
                         wrapper.rowContentObj.put(FS_PACKAGE_QUALIFIER + 'Revenue_GL_Account__c', NULL);
                         BillingLineActions.associateDefaultGLAccounts(new List<Billing_Line__c>{
                             (Billing_Line__c) wrapper.rowContentObj
                         });
                     }
                 }
             }
        }
        else if (masterRecord.getSobjectType() == globalDescribe.get(ENTRY_TYPE_AP)) {
            for (LineWrapper wrapper : allLinesMap.values()) {
                if (wrapper.rowContentObj.getSObjectType() == globalDescribe.get(ENTRY_TYPE_AP_LINE)) {
                    if (wrapper.rowContentObj.Id == NULL) {
                        wrapper.rowContentObj.put(FS_PACKAGE_QUALIFIER + 'Expense_GL_Account__c', NULL);
                        AccountPayableLineActions.associateDefaultExpenseGLAccount(new List<Account_Payable_Line__c>{
                            (Account_Payable_Line__c) wrapper.rowContentObj
                        });
                    }
                }
            }
        }
        else if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_PURCHASE_ORDER)) {
            Set<Id> productIds = new Set<Id>();
            List<LineWrapper> itemToUpdate = new List<LineWrapper>();
            for (LineWrapper wrapper : allLinesMap.values()) {
                if (wrapper.rowContentObj.getSObjectType() == globalDescribe.get(ENTRY_TYPE_PURCHASE_ORDER_LINE)) {
                    if (wrapper.rowContentObj.Id == NULL && wrapper.rowContentObj.get(ERP_PACKAGE_QUALIFIER + 'Product__c') != NULL) {
                        productIds.add((Id) wrapper.rowContentObj.get(ERP_PACKAGE_QUALIFIER + 'Product__c'));
                        itemToUpdate.add(wrapper);
                    }
                }
            }
            if (!productIds.isEmpty()) {
                Map<Id, SObject> pptByProduct = getPPByProductAndMasterRecord(productIds, masterRecord);
                for (LineWrapper wrapper : itemToUpdate) {
                    if (pptByProduct.containsKey((Id) wrapper.rowContentObj.get(ERP_PACKAGE_QUALIFIER + 'Product__c'))) {
                        wrapper.rowContentObj.put(
                            ERP_PACKAGE_QUALIFIER + 'Unit_Price__c',
                            (Decimal) pptByProduct.get((Id) wrapper.rowContentObj.get(ERP_PACKAGE_QUALIFIER + 'Product__c')).get(ERP_PACKAGE_QUALIFIER + 'Unit_Price__c')
                        );
                    }

                }
            }

        }
        return NULL;
    }

    public enum Direction {
        PREV, NEXT
    }

    public enum JumpSize {
        SINGLE, MULTI
    }

    private Integer lineCount = null;
    private final static Integer OFFSET_LIMIT = 2000;
    private Integer prevRecLimit { get; set; }
    private Integer prevOffset { get; set; }

    public void initAllLines() {

        if (prevRecLimit != recLimit) {
            prevOffset = null;
            prevRecLimit = recLimit;
        }
        Direction moveDirection = prevOffset == null || offset > prevOffset ? Direction.NEXT : Direction.PREV;
        JumpSize jump = prevOffset == null || (Math.abs(prevOffset - offset) <= recLimit) ? JumpSize.SINGLE : JumpSize.MULTI;

        removedRows.clear();

        if (masterRecord.Id != NULL) {
            String masterRecordIdValue = masterRecord.Id;
            //============================================================================
            // Prepare SOQL Query to query configuration and display information. Since at this point,
            // user MUST have access to object since bound to custom button on related list
            // on record detail page.
            // FLS is not handles as all queried fields are bound to output fields on VF Page.
            //============================================================================
            if (lineCount == null) {
                List<String> conditions = new List<String>{
                        getCurrentEntryTypeApiName() + ' =: masterRecordIdValue'
                };
                String query = String.format('SELECT {0} FROM {1} {2}', new List<String>{
                        String.join(new List<String>{'Count(Id) c0unt'}, ','),
                        getCurrentEntryLineTypeApiName(),
                        (!conditions.isEmpty() ? ' WHERE ' + String.join(conditions, ' AND ') : '')
                });
                List<AggregateResult> results = (List<AggregateResult>)Database.query(query);
                lineCount = !results.isEmpty() ? (Integer)results[0].get('c0unt') : 0;
            }

            String lastLineName = null;
            Datetime lastLineCreatedDate = null;
            Boolean isOffsetAvailable = (offset + recLimit) <= OFFSET_LIMIT;
            if (!isOffsetAvailable) {
                if (moveDirection == Direction.NEXT && jump == JumpSize.SINGLE) {
                    LineWrapper lastLine = allLinesMap != null && allLines != null ? allLines[allLines.size() - 1] : null;
                    lastLineName = lastLine != null ? (String)lastLine.rowContentObj.get('Name') : null;
                    lastLineCreatedDate = lastLine != null ? (Datetime)lastLine.rowContentObj.get('CreatedDate') : null;
                }
                if (lineCount - offset < OFFSET_LIMIT - recLimit) {
                    Integer reverseOffset = lineCount - offset;
                    Integer reverseLimit = 1;
                    List<String> conditions = new List<String>{getCurrentEntryTypeApiName() + ' =: masterRecordIdValue'};
                    String query = String.format('SELECT {0} FROM {1} {2}', new List<String>{
                            String.join(new List<String>{'Name', 'CreatedDate'}, ','),
                            getCurrentEntryLineTypeApiName(),
                            (!conditions.isEmpty() ? ' WHERE ' + String.join(conditions, ' AND ') : '')
                                    + ' ORDER BY CreatedDate DESC,Name DESC'
                                    + ' LIMIT ' + reverseLimit
                                    + ' OFFSET ' + reverseOffset
                    });
                    List<SObject> lines = Database.query(query);
                    if (!lines.isEmpty()) {
                        lastLineName = (String)lines[0].get('Name');
                        lastLineCreatedDate = (Datetime)lines[0].get('CreatedDate');
                    }
                } else if (moveDirection == Direction.PREV && jump == JumpSize.SINGLE) {
                    LineWrapper firstLine = allLinesMap != null && allLines != null && !allLines.isEmpty() ? allLines[0] : null;
                    String firstLineName = firstLine != null ? (String)firstLine.rowContentObj.get('Name') : null;
                    Datetime firstLineCreatedDate = firstLine != null ? (Datetime)firstLine.rowContentObj.get('CreatedDate') : null;
                    List<String> conditions = new List<String>{getCurrentEntryTypeApiName() + ' =: masterRecordIdValue'};
                    if (firstLineName != null) {
                        conditions.add('Name <: firstLineName');
                    }
                    if (firstLineCreatedDate != null) {
                        conditions.add('CreatedDate <=: firstLineCreatedDate');
                    }
                    String query = String.format('SELECT {0} FROM {1} {2}', new List<String>{
                            String.join(new List<String>{'Name', 'CreatedDate'}, ','),
                            getCurrentEntryLineTypeApiName(),
                            (!conditions.isEmpty() ? ' WHERE ' + String.join(conditions, ' AND ') : '')
                                    + ' ORDER BY CreatedDate DESC,Name DESC'
                                    + ' LIMIT ' + (recLimit + 1)
                    });
                    List<SObject> lines = Database.query(query);
                    if (!lines.isEmpty()) {
                        lastLineName = (String)lines[lines.size() - 1].get('Name');
                        lastLineCreatedDate = (Datetime)lines[lines.size() - 1].get('CreatedDate');
                    }
                }
            }

            Set<String> fields = new Set<String>{'Id', 'CreatedDate', getCurrentEntryTypeApiName()};
            for (Schema.FieldSetMember f: this.getDetailFields()) {
                fields.add(f.getFieldPath());
            }
            List<String> conditions = new List<String>{
                    getCurrentEntryTypeApiName() + ' =: masterRecordIdValue'
            };

            if (!isOffsetAvailable) {
                if (lastLineName != null) {
                    conditions.add('Name >: lastLineName');
                }
                if (lastLineCreatedDate != null) {
                    conditions.add('CreatedDate >=: lastLineCreatedDate');
                }
            }

            allLinesMap = new Map < Integer, MassAddEditLineComponentCntrl.LineWrapper > ();
            rowIndex = 0;

            String query = String.format('SELECT {0} FROM {1} {2}', new List<String>{
                    String.join(new List<String>(fields), ','),
                    getCurrentEntryLineTypeApiName(),
                    (!conditions.isEmpty() ? ' WHERE ' + String.join(conditions, ' AND ') : '')
                            + ' ORDER BY CreatedDate ASC,Name ASC'
                            + ' LIMIT ' + recLimit
                            + (isOffsetAvailable ? (' OFFSET ' + offset) : '')
            });
            List<SObject> lines = Database.query(query);
            for (SObject line: lines) {
                allLinesMap.put(rowIndex, new LineWrapper(rowIndex, line, wrappedDetailFields));
                rowIndex++;
            }
            this.allLines = allLinesMap.values();
            //============================================================================
            // Prepare SOQL Query to perform aggregate query. Since at this point,
            // user MUST have access to object since bound to custom button on related list
            // on record detail page.
            //============================================================================
            recordSetSize = (Integer) Database.countQuery('SELECT count() FROM ' + getCurrentEntryLineTypeApiName() + ' WHERE ' + getCurrentEntryTypeApiName() + ' = :masterRecordIdValue');
        }
        else {
            allLines = new List < LineWrapper > ();
        }
        prevOffset = offset;
    }

    public PageReference deleteLine() {
        deleteLines(new Set<Integer>{indexOfRowToDelete});
        return NULL;
    }

    private void deleteLines(Set<Integer> rowIndexSetToDelete) {
        for (Integer index : rowIndexSetToDelete) {
            LineWrapper deletedLine = allLinesMap.remove(index);
            if (deletedLine.rowContentObj.Id != NULL) {
                removedRows.add(deletedLine);
            }
        }
        allLines = allLinesMap.values();
    }

    public PageReference saveAndRefresh() {
        try {
            isError = false;
            if (isAvalaraTaxCalcEnabled && !isHeaderLevelPostEnabled && !isAppliedRecords()) {
                handleAvalaraSalesTaxLines();
            }
            saveLines();
            if (isAvalaraTaxCalcEnabled && !isHeaderLevelPostEnabled && !isAppliedRecords()) {
                calculateAvalaraTaxesAsync(false);
            }
            refreshDataInMasterRecord();
        }
        catch (Exception ex) {
            isError = true;
            ApexPages.addMessages(ex);
            return NULL;
        }
        return NULL;
    }

    public PageReference saveAndComplete() {
        PageReference pr = NULL;
        try {
            if (isAvalaraTaxCalcEnabled && !isHeaderLevelPostEnabled && !isAppliedRecords()) {
                handleAvalaraSalesTaxLines();
            }
            saveLines();
            if (isAvalaraTaxCalcEnabled && !isHeaderLevelPostEnabled && !isAppliedRecords()) {
                calculateAvalaraTaxesAsync(false);
            }
            pr =  new PageReference('/' + masterRecord.Id);
        }
        catch (Exception ex) {
            isError = true;
            ApexPages.addMessages(ex);
        }
        return pr;
    }

    public PageReference redirectToNew() {
        PageReference pr = NULL;
        pr =  new PageReference('/' + masterRecord.getSObjectType().getDescribe().getKeyPrefix() + '/e');
        pr.getParameters().put('retURL', masterRecord.Id);
        return pr;
    }

    public PageReference saveAndPost() {
        PageReference pr = NULL;
        try {
            if ((masterRecord.getSobjectType() == globalDescribe.get(ENTRY_TYPE_AP) || masterRecord.getSobjectType() == globalDescribe.get(ENTRY_TYPE_BILLING))
                && AbstractTaxService.isLedgerTaxSettingsEmpty(masterRecord)) {
                throw new AvaTaxService.AvaTaxException(TaxService.getNoTaxSettingErrorMessage(false));
            }

            if (isAvalaraTaxCalcEnabled && !isHeaderLevelPostEnabled && !isAppliedRecords()) {
                handleAvalaraSalesTaxLines();
            }
            saveLines();
            refreshDataInMasterRecord();
            postMasterRecord();
            pr =  new PageReference('/' + masterRecord.Id);
        }
        catch (Exception ex) {
            isError = true;
            ApexPages.addMessages(ex);
        }
        return pr;
    }

    private void postMasterRecord() {
        List<PostResult> results = new List<PostResult>();
        if (FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
            new PostProcessor().post(new List<Id> {masterRecord.Id});
        } else {
            if (masterRecord.getSobjectType() == globalDescribe.get(ENTRY_TYPE_AP)) {
                results = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{(Account_Payable__c) masterRecord});
            }
            else if (masterRecord.getSobjectType() == globalDescribe.get(ENTRY_TYPE_BILLING)) {
                AbstractPostHandler postHandler = new BillingPostHandler();
                AsyncPostHandlersExecutor asyncPHExecutor = new AsyncPostHandlersExecutor(new List<Billing__c>{(Billing__c) masterRecord}, postHandler);
                System.enqueueJob(asyncPHExecutor);
            }
            else if (masterRecord.getSobjectType() == globalDescribe.get(ENTRY_TYPE_JOURNAL_ENTRY)) {
                results = JournalEntryPostService.postJournalEntries(new List<Journal_Entry__c>{(Journal_Entry__c) masterRecord});
            }
        }

        if (!results.isEmpty() && !results[0].isSuccess && results[0].errors.size() > 0) {
            throw new DMLException(results[0].errors[0].message);
        }
    }

    private void saveLines() {
        try {
            Boolean allFieldsValid = validateRequiredFields();
            if (!allFieldsValid) {
                throw new MassAddEditLineCustomFieldValidationException(VALIDATION_ERROR);
            }
            //we can't do upsert on generic List<SObject>
            //so need to split them
            List < SObject > newLinesForInsert = new List < SObject > ();
            List < SObject > existedLinesForUpdate = new List < SObject > ();
            for (LineWrapper line: allLines) {
                if (line.rowContentObj.Id == NULL) {
                    newLinesForInsert.add(line.rowContentObj);
                }
                else {
                    existedLinesForUpdate.add(line.rowContentObj);
                }
            }
            //do DML
            SFDCSecurityUtils.BYPASS_INTERNAL_FLS_AND_CRUD = true;
            List<String> fieldsToFLSChecks = new List<String>();
            for (Schema.FieldSetMember f : this.getDetailFields()) {
                fieldsToFLSChecks.add(f.getFieldPath());
            }
            if (!newLinesForInsert.isEmpty()) {
                SFDCSecurityUtils.insertCheckCRUDAndFLS(newLinesForInsert, fieldsToFLSChecks);
            }
            if (!existedLinesForUpdate.isEmpty()) {
                SFDCSecurityUtils.updateCheckCRUDAndFLS(existedLinesForUpdate, fieldsToFLSChecks);
            }
            if (!removedRows.isEmpty()) {
                List < SObject > linesToDelete = new List < SObject > ();
                for (LineWrapper line : removedRows) {
                    linesToDelete.add(line.rowContentObj);
                }
                SFDCSecurityUtils.deleteCheckCRUDAndFLS(linesToDelete);
                removedRows.clear();
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private Boolean validateRequiredFields() {
        Boolean valid = true;
        for (LineWrapper line: allLines) {
            for (FieldWrapper wrappedField : wrappedDetailFields) {
                if (wrappedField.isRequired && line.rowContentObj.get(wrappedField.field.getFieldPath()) == NULL) {
                    line.errorMap.put(wrappedField.field.getFieldPath(), true);
                    valid = false;
                }
            }
        }
        return valid;
    }

    private Boolean validateRequiredFieldsForAvalara() {
        //get all fields presented in line's fields set
        Set<SObjectField> fieldsInFieldSet = new Set<SObjectField>();
        for (FieldWrapper wrappedField : wrappedDetailFields) {
            fieldsInFieldSet.add(wrappedField.field.getSObjectField());
        }
        //validate all required for Avalara fields are presented in related field set
        return fieldsInFieldSet.containsAll(requiredFieldsForAvalara);
    }

    private void calculateAvalaraTaxesAsync(Boolean doCommit) {
        //works for Billing records only
        if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_BILLING)) {
            if (isThereAvalaraSalesProductLine()) {
                AvaTaxAsyncTransactionHandler taxTransactionHandler =
                    new AvaTaxAsyncTransactionHandler(AvaTaxAsyncTransactionHandler.AvaTaxContext.CREATE, new Set<Id>{masterRecord.Id}, doCommit);

                System.enqueueJob(taxTransactionHandler);
            }
        }
    }

    private Boolean isAppliedRecords() {
        Boolean result = false;
        if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_BILLING)) {
            result = SourceDocumentUpdateFieldValidator.hasAppliedRecord(masterRecord);
        }
        return result;
    }

    private void handleAvalaraSalesTaxLines() {
        //works only for Billings
        if (masterRecord.getSObjectType() == globalDescribe.get(ENTRY_TYPE_BILLING)) {
            Billing__c theBilling = AvaTaxHelper.queryBillingById(new Set<Id>{masterRecord.Id}, false)[0];
            try {
                Boolean allFieldsValid = validateRequiredFields();
                if (!allFieldsValid) {
                    throw new MassAddEditLineCustomFieldValidationException(VALIDATION_ERROR);
                }

                if (!validateRequiredFieldsForAvalara()) {
                    throw new MassAddEditLineCustomFieldValidationException(AVALARA_BILLING_LINE_FIELD_SET_VALIDATION_ERROR);
                }

                if (!AvaTaxHelper.isLedgerCurrencySupportedByAvaTaxCalculation(theBilling.Ledger__c)
                        || !isThereProductLine()) {

                    removeOldSalesTaxLine();
                }
                else if (isThereProductLine()) {
                    AvaTaxService.CreateTransactionModel request = getCreateTransactionModel(theBilling);
                    AvaTaxHelper.sourceRecord = theBilling;
                    AvaTaxService.TransactionModel response = AvaTaxHelper.calcTax(request);
                    upsertSalesTaxLine(response, theBilling);
                }
            }
            catch (Exception ex) {
                throw ex;
            }
        }
    }

    public Boolean isThereProductLine() {
        //check content on screen first
        AvaTaxHelper.sourceRecordMap = new Map<Id, SObject> {masterRecord.Id => masterRecord};
        for (LineWrapper eachLine : allLines) {
            if (eachLine.rowContentObj.get(FS_PACKAGE_QUALIFIER + 'Product__c') != NULL
                && (Id) eachLine.rowContentObj.get(FS_PACKAGE_QUALIFIER + 'Product__c') != AvaTaxHelper.getSalesTaxProductId(masterRecord)) {

                return true;
            }
        }
        return false;
    }

    public Boolean isThereAvalaraSalesProductLine() {
        for (LineWrapper eachLine : allLines) {
            if (eachLine.rowContentObj.get(FS_PACKAGE_QUALIFIER + 'Product__c') != NULL
                && (Id) eachLine.rowContentObj.get(FS_PACKAGE_QUALIFIER + 'Product__c') == AvaTaxHelper.getSalesTaxProductId(masterRecord)) {

                return true;
            }
        }
        return false;
    }

    public SObject removeOldSalesTaxLine() {
        Set<Integer> rowIndexSetToDelete = new Set<Integer>();
        SObject result;

        for (LineWrapper eachLine : allLines) {
            if ((Id) eachLine.rowContentObj.get(FS_PACKAGE_QUALIFIER + 'Product__c') == AvaTaxHelper.getSalesTaxProductId(masterRecord)) {
                rowIndexSetToDelete.add(eachLine.rowIndex);
                result = eachLine.rowContentObj;
            }
        }

        if (!rowIndexSetToDelete.isEmpty()) {
            deleteLines(rowIndexSetToDelete);
        }

        Set<Id> currentlyRemovedRows = new Set<Id>();
        for (LineWrapper removedRow : removedRows) {
            if (removedRow.rowContentObj.Id != NULL) {
                currentlyRemovedRows.add(removedRow.rowContentObj.Id);
            }
        }

        List<Billing_Line__c> linesToDeleteImmediately = new List<Billing_Line__c>();
        for (Billing_Line__c billLine : AvaTaxHelper.queryExistedSalesTaxBillingLines(new Set<Id>{masterRecord.Id}, AvaTaxHelper.getSalesTaxProductIds(new List<SObject> {masterRecord}))) {
            if (!currentlyRemovedRows.contains(billLine.Id)) {
                linesToDeleteImmediately.add(billLine);
            }
        }

        if (!linesToDeleteImmediately.isEmpty()) {
            SFDCSecurityUtils.deleteCheckCRUDAndFLS(linesToDeleteImmediately);
        }

        return result;
    }

    public void upsertSalesTaxLine(AvaTaxService.TransactionModel avaTaxTransaction, Billing__c theBilling) {
        SObject oldSalesTaxLine = removeOldSalesTaxLine();

        Billing_Line__c newSalesTaxLine = new Billing_Line__c();
        newSalesTaxLine.Billing__c = masterRecord.Id;
        newSalesTaxLine.Date__c = avaTaxTransaction.avaTaxDate;
        newSalesTaxLine.Revenue_GL_Account__c = AvaTaxHelper.getAvaTaxGLAccount(theBilling);
        newSalesTaxLine.Product__c = AvaTaxHelper.getSalesTaxProductId(theBilling);
        newSalesTaxLine.Hours_Units__c = 1;
        newSalesTaxLine.Rate__c = avaTaxTransaction.totalTax * AvaTaxHelper.getCurrencyConversionRate(theBilling);
        newSalesTaxLine.List_Price__c = 0;

        if (oldSalesTaxLine != NULL) {
            Map<String, Object> oldLineFields = oldSalesTaxLine.getPopulatedFieldsAsMap();
            newSalesTaxLine.Project__c = oldLineFields.containsKey(FS_PACKAGE_QUALIFIER + 'Project__c') ? (Id) oldSalesTaxLine.get(FS_PACKAGE_QUALIFIER + 'Project__c') : NULL;
            newSalesTaxLine.Project_Task__c = oldLineFields.containsKey(FS_PACKAGE_QUALIFIER + 'Project_Task__c') ? (Id) oldSalesTaxLine.get(FS_PACKAGE_QUALIFIER + 'Project_Task__c') : NULL;
            newSalesTaxLine.GL_Account_Variable_1__c = oldLineFields.containsKey(FS_PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c') ? (Id) oldSalesTaxLine.get(FS_PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c') : NULL;
            newSalesTaxLine.GL_Account_Variable_2__c = oldLineFields.containsKey(FS_PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c') ? (Id) oldSalesTaxLine.get(FS_PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c') : NULL;
            newSalesTaxLine.GL_Account_Variable_3__c = oldLineFields.containsKey(FS_PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c') ? (Id) oldSalesTaxLine.get(FS_PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c') : NULL;
            newSalesTaxLine.GL_Account_Variable_4__c = oldLineFields.containsKey(FS_PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c') ? (Id) oldSalesTaxLine.get(FS_PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c') : NULL;
        }

        putNewLine(newSalesTaxLine);
    }

    public AvaTaxService.CreateTransactionModel getCreateTransactionModel(Billing__c theBilling) {
        AvaTaxService.CreateTransactionModel result = new AvaTaxService.CreateTransactionModel();
        result.companyCode = AvaTaxHelper.getCompanyCode(theBilling);
        result.type = AvaTaxService.DocumentType.SalesOrder;
        result.avaTaxDate = theBilling.Date__c;
        result.customerCode = theBilling.Customer__c;
        result.businessIdentificationNo = theBilling.Customer__r.VAT_Business_Identification_Number__c;
        result.entityUseCode = theBilling.Customer__r.Entity_Use_Code__c;
        result.exemptionNo = theBilling.Customer__r.Exemption_Number__c;
        result.addresses = AvaTaxHelper.getAddresses(AvaTaxHelper.getOriginAddressInfo(theBilling), AvaTaxHelper.getDestinationAddressInfo(theBilling), theBilling);
        result.currencyCode = 'USD';//currently we support only USD

        result.lines = getLines(theBilling);

        result.doCommit = false;

        return result;
    }

    private List<AvaTaxService.LineItemModel> getLines(Billing__c bill) {
        //get all Non-Sales Tax Product Ids from lines
        Set<Id> productIds = new Set<Id>();
        Set<Id> existedLinesIds = new Set<Id>();
        for (LineWrapper eachLine : allLines) {
            if (eachLine.rowContentObj.get(FS_PACKAGE_QUALIFIER + 'Product__c') != NULL
                && (Id) eachLine.rowContentObj.get(FS_PACKAGE_QUALIFIER + 'Product__c') != AvaTaxHelper.getSalesTaxProductId(bill)) {

                productIds.add((Id) eachLine.rowContentObj.get(FS_PACKAGE_QUALIFIER + 'Product__c'));

                if (eachLine.rowContentObj.Id != NULL) {
                    existedLinesIds.add(eachLine.rowContentObj.Id);
                }
            }
        }

        Map<Id, Product2> productMap = new Map<Id, Product2>(DomainUtils.getProductsById(productIds));
        AvaTaxHelper.sourceRecordMap = new Map<Id, SObject> {bill.Id => bill};
        List<Billing_Line__c> allExistedLines = AvaTaxHelper.queryTaxableBillingLinesByBillingId(new Set<Id>{bill.Id});

        List<Billing_Line__c> lineItemModelSources = new List<Billing_Line__c>();
        for (LineWrapper eachLine : allLines) {
            lineItemModelSources.add((Billing_Line__c) eachLine.rowContentObj);
        }

        for (Billing_Line__c eachExistedLine : allExistedLines) {
            if (!existedLinesIds.contains(eachExistedLine.Id)) {
                lineItemModelSources.add(eachExistedLine);
                productMap.put(eachExistedLine.Product__c, eachExistedLine.Product__r);
            }
        }

        List<AvaTaxService.LineItemModel> result = new List<AvaTaxService.LineItemModel>();
        for (Billing_Line__c eachLine : lineItemModelSources) {
            //exclude Tax Line and lines without Product
            if (eachLine.Product__c != NULL && eachLine.Product__c != AvaTaxHelper.getSalesTaxProductId(bill)) {
                AvaTaxService.LineItemModel tempLine = new AvaTaxService.LineItemModel();
                tempLine.amount = (eachLine.Hours_Units__c * eachLine.Rate__c) / AvaTaxHelper.getCurrencyConversionRate(bill);
                tempLine.quantity = Math.abs(eachLine.Hours_Units__c);
                AvaTaxHelper.putItemCodeOnLine(tempLine, productMap.get(eachLine.Product__c));
                tempLine.description = productMap.get(eachLine.Product__c).Description;
                result.add(tempLine);
            }
        }
        return result;
    }

}