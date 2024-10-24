public without sharing class FinancialSuiteUtils {

    //============= Fake Id generation to use in Financial Reporter ===========================
    public static Integer sNUM = 1;

    public static String getFakeId(Schema.SObjectType sot) {
        String result = String.valueOf(sNUM++);
        return sot.getDescribe().getKeyPrefix() + '0'.repeat(12 - result.length()) + result;
    }
    //=========================================================================================

    public static Boolean isValidId(String idValue, SObjectType sType) {
        Boolean validity = true;
        if (String.isBlank(idValue)) {
            validity = false;
        }
        else {
            try {
                Id checkedId = (Id) idValue;
                if (checkedId.getSobjectType() != sType) {
                    validity = false;
                }
            }
            catch (Exception ex) {
                validity = false;
            }
        }
        return validity;
    }

    public static Integer getAvailableDMLRows() {
        return Limits.getLimitDMLRows() - Limits.getDMLRows();
    }

    public static String formatFieldStrings(Schema.SObjectType sObjectType, List<String> fieldsList) {
        String errorFields = '';
        Schema.DescribeSObjectResult result = sObjectType.getDescribe();
        Map<String, Schema.SObjectField> sObjectMap = result.fields.getMap();
        for (Integer i = 0; i < fieldsList.size(); i++)  {
            errorFields += sObjectMap.get(fieldsList[i]).getDescribe().getLabel() + (i == fieldsList.size() - 2 ? ', or  ' : ', ');
        }

        return errorFields.subString(0, errorFields.length() - 2);
    }

    public static String formatFieldStrings(List<SObjectField> fieldsList) {
        String errorFields = '';
        for (Integer i = 0; i < fieldsList.size(); i++)  {
            errorFields += fieldsList[i].getDescribe().getLabel() + (i == fieldsList.size() - 2 ? ', or  ' : ', ');
        }

        return errorFields.subString(0, errorFields.length() - 2);
    }

    public static String leftPad(String value, Integer numOfZeros) {
        String theZeros = '';

        for (Integer i = 0; i < numOfZeros; i++) {
            theZeros += '0';
        }

        return theZeros + value;
    }
    
    public static Boolean isFieldValueChanged(SObjectField fieldToken, SObject oldObject, SObject newObject) {
        Boolean retVal = false;
        if (fieldToken.getDescribe().getType() == Schema.DisplayType.CURRENCY
                && ((Decimal) oldObject.get(fieldToken)).setScale(2, System.RoundingMode.HALF_UP) !=
                        ((Decimal) newObject.get(fieldToken)).setScale(2, System.RoundingMode.HALF_UP)) {

            retVal = true;
        }
        else if (fieldToken.getDescribe().getType() != Schema.DisplayType.CURRENCY
                    && oldObject.get(fieldToken) != newObject.get(fieldToken)) {

            retVal = true;
        }
        return retVal;
    }

    public static List<ApexPage> getApexPages(Set<String> apexPageNames) {
        List<String> queryFields = new List<String>{
            'Id', 'Name', 'NameSpacePrefix'
        };
        String queryCondition =
            'Name IN :apexPageNames ORDER BY NameSpacePrefix NULLS LAST';

        SOQLBuilder theQuery = new SOQLBuilder(ApexPage.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        try {
            return (List<ApexPage>) Database.query(theQuery.toSOQL());
        }
        catch (Exception ex) {
            return new List<ApexPage>();
        }
    }

    public static String getApexPagePackageName(String apexPageName) {
        ApexPage thePage;
        String packageName;

        List<String> queryFields = new List<String>{
            'Id', 'Name', 'NameSpacePrefix'
        };
        String queryCondition =
            'Name = :apexPageName ORDER BY NameSpacePrefix NULLS FIRST LIMIT 1';

        SOQLBuilder theQuery = new SOQLBuilder(ApexPage.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        try {
            thePage = (ApexPage) Database.query(theQuery.toSOQL());
            packageName = thePage.NameSpacePrefix;
        }
        catch (Exception ex) {
            
        }
        
        return packageName;
    }

    public static String getSalesforceEdition() {
        String orgId = UserInfo.getOrganizationId();

        return getOrganization(orgId).OrganizationType;
    }

    public static String instanceName {
        get {
            if (instanceName == NULL) {
                instanceName = getOrganization(NULL).InstanceName;
            }
            return instanceName.toLowerCase();
        }
        set;
    }

    public static Boolean isOrganizationInstanceSandbox {
        get {
            if (isOrganizationInstanceSandbox == NULL) {
                isOrganizationInstanceSandbox = getOrganization(NULL).IsSandbox;
            }
            return isOrganizationInstanceSandbox;
        }
        set;
    }

    private static Organization getOrganization(Id orgId) {
        List<String> queryFields = new List<String>{
            'Id', 'OrganizationType', 'IsSandbox', 'InstanceName'
        };
        String queryCondition;
        if (orgId != NULL) {
            queryCondition = 'Id = :orgId ';
        }


        SOQLBuilder theQuery = new SOQLBuilder(Organization.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields);

        if (orgId != NULL) {
            theQuery.setCondition(queryCondition);
        }

        theQuery.setLimit(1);
        return (Organization) Database.query(theQuery.toSOQL());
    }

    public static String getFullVFPageUrl(String pageAPIName, String baseUrl) {
        String result;
        String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER.replaceAll('_', '');

        String salesforceBaseUrl =
            Test.isRunningTest()
                ? TestDataSuite.salesforceUrl
                : (String.isNotBlank(baseUrl)) ? baseUrl : currentRequestBaseUrl();

        result = salesforceBaseUrl;

        String pagePackageQualifier = FinancialSuiteUtils.getApexPagePackageName(pageAPIName);
        //in case of using External VF Page (Custom Page - not from FS package and not from any other packages)
        if (!String.isBlank(PACKAGE_QUALIFIER)
                && result.containsIgnoreCase(PACKAGE_QUALIFIER)
                && pagePackageQualifier == NULL) {

            result = result.toLowerCase().replace(PACKAGE_QUALIFIER.toLowerCase(), 'c');
        }//in case of using External VF Page which is included into another managed package(has its own package qualifier)
        else if (!String.isBlank(PACKAGE_QUALIFIER)
                    && result.containsIgnoreCase(PACKAGE_QUALIFIER)
                    && pagePackageQualifier != NULL) {

            result = result.toLowerCase().replace(PACKAGE_QUALIFIER.toLowerCase(), pagePackageQualifier);
        }

        result = result + '/apex/' + pageAPIName;
        return result;
    }

    public static String currentRequestBaseUrl() {
        String rootDomain = '.com/';
        String currentUrl = URL.getCurrentRequestUrl().toExternalForm();
        Integer startIndex = currentUrl.indexOfIgnoreCase(rootDomain);
        return currentUrl.substring(0, startIndex + rootDomain.length() - 1);
    }

    public static String fullAdminPermissionId {
        get {
            if (fullAdminPermissionId == NULL) {
                List<String> queryFields = new List<String>{
                    'Id'
                };

                String queryCondition = 'Name = \'AS_Full_Admin\'';

                SOQLBuilder theQuery = new SOQLBuilder(PermissionSet.SObjectType);
                theQuery
                    .setEnforceFLS(false)
                    .selectFields(queryFields)
                    .setCondition(queryCondition)
                    .setLimit(1);

                PermissionSet theSet = (PermissionSet) Database.query(theQuery.toSOQL());
                fullAdminPermissionId = theSet.Id;
            }
            return fullAdminPermissionId;
        }
        set;
    }

    public static String accountingManagerPermissionId {
        get {
            if (accountingManagerPermissionId == NULL) {
                List<String> queryFields = new List<String>{
                    'Id'
                };

                String queryCondition = 'Name = \'Accounting_Manager\'';

                SOQLBuilder theQuery = new SOQLBuilder(PermissionSet.SObjectType);
                theQuery
                    .setEnforceFLS(false)
                    .selectFields(queryFields)
                    .setCondition(queryCondition)
                    .setLimit(1);

                PermissionSet theSet = (PermissionSet) Database.query(theQuery.toSOQL());
                accountingManagerPermissionId = theSet.Id;
            }
            return accountingManagerPermissionId;
        }
        set;
    }

    public static String cashOutBankingPermissionId {
        get {
            if (cashOutBankingPermissionId == NULL) {
                List<String> queryFields = new List<String>{
                    'Id'
                };

                String queryCondition = 'Name = \'Cash_Out_Banking\'';

                SOQLBuilder theQuery = new SOQLBuilder(PermissionSet.SObjectType);
                theQuery
                    .setEnforceFLS(false)
                    .selectFields(queryFields)
                    .setCondition(queryCondition)
                    .setLimit(1);

                PermissionSet theSet = (PermissionSet) Database.query(theQuery.toSOQL());
                cashOutBankingPermissionId = theSet.Id;
            }
            return cashOutBankingPermissionId;
        }
        set;
    }

    public static List<OrgWideEmailAddress> orgWideEmailAddressList {
        get {
            if (orgWideEmailAddressList == NULL) {
                List<String> queryFields = new List<String>{
                    'Id',
                    'DisplayName',
                    'Address'
                };

                SOQLBuilder theQuery = new SOQLBuilder(OrgWideEmailAddress.SObjectType);
                theQuery
                    .setEnforceFLS(false)
                    .selectFields(queryFields)
                    .setLimit(100);

                orgWideEmailAddressList = (List<OrgWideEmailAddress>) Database.query(theQuery.toSOQL());
            }
            return orgWideEmailAddressList;
        }
        set;
    }

    public static Map<String, OrgWideEmailAddress> orgWideEmailAddressMapByAddress {
        get {
            if (orgWideEmailAddressMapByAddress == NULL) {
                orgWideEmailAddressMapByAddress = new Map<String, OrgWideEmailAddress>();
                for (OrgWideEmailAddress address : orgWideEmailAddressList) {
                    orgWideEmailAddressMapByAddress.put(address.Address, address);
               }
            }
            return orgWideEmailAddressMapByAddress;
        }
        set;
    }

    public static Map<String, String> getPageAPINameToFullVFPageURL(Set<String> pageAPINameSet, String baseUrl) {
        Map<String, String> result = new Map<String, String>();
        for (String eachAPIName : pageAPINameSet) {
            String pageURL = FinancialSuiteUtils.getFullVFPageUrl(eachAPIName, baseUrl);
            result.put(eachAPIName, pageURL);
        }
        return result;
    }

    public static Map<Id, Set<String>> getEmailAddressesFromAccountContactRoles(Set<Id> accountIds, Set<String> contactRoleNames) {
        Map<Id, Set<String>> result = new Map<Id, Set<String>>();
        for (AccountContactRole eachRole : DomainUtils.getAccountContactRoleByAccountAndRole(accountIds, contactRoleNames)) {
            if (result.containsKey(eachRole.AccountId)) {
                result.get(eachRole.AccountId).add(eachRole.Contact.Email);
            }
            else {
                result.put(eachRole.AccountId, new Set<String>{eachRole.Contact.Email});
            }
        }

        return result;
    }

    public static Map<Id, Set<String>> getEmailAddressesFromAccountContactRelation(Set<Id> accountIds, Set<String> contactRoleNames) {
        Map<Id, Set<String>> result = new Map<Id, Set<String>>();
        for (SObject eachRelation : DomainUtils.getAccountContactRelationByAccountAndRole(accountIds, contactRoleNames)) {
            Id accountId = (Id) eachRelation.get('AccountId');
            String contactEmail = (String) eachRelation.getSObject('Contact').get('Email');
            if (result.containsKey(accountId)) {
                result.get(accountId).add(contactEmail);
            }
            else {
                result.put(accountId, new Set<String>{contactEmail});
            }
        }

        return result;
    }

    public static Map<Id, Set<String>> getEmailAddressesFromAccountContact(Set<Id> accountIds, Set<String> roleName) {
        Map<Id, Set<String>> accountIdToEmails = getEmailAddressesFromAccountContactRoles(accountIds, roleName);

        if (GlobalVariables.isContactsToMultipleAccountsEnabled) {
            Map<Id, Set<String>> accountIdToEmailsRelation = getEmailAddressesFromAccountContactRelation(accountIds, roleName);

            if (accountIdToEmails.isEmpty()) {
                accountIdToEmails.putAll(accountIdToEmailsRelation);
            } else {
                for (Id accId : accountIdToEmails.keySet()) {
                    if (accountIdToEmailsRelation.containsKey(accId)) {
                        accountIdToEmails.get(accId).addAll(accountIdToEmailsRelation.get(accId));
                    }
                }
            }
        }

        return accountIdToEmails;
    }

    public static Boolean canSendEmail() {
        try {
            Messaging.reserveSingleEmailCapacity(1);
            return true;
        }
        catch (Exception e) {
            return false;
        }
    }

    //36-characters UUID generation
    public static String getUUID() {
        String uuidString = getUUIDNoTestCheck();
        return Test.isRunningTest() ? '1239891823782378' : uuidString;
    }
    public static String getUUIDNoTestCheck(){
        Blob aesKey = Crypto.GenerateAESKey(128);
        String hexString = EncodingUtil.ConvertToHex(aesKey);
        return hexString.subString(0, 8)+ '-' + hexString.subString(8, 12) + '-' + hexString.subString(12, 16) + '-' + hexString.subString(16, 20) + '-' + hexString.subString(20);
    }
    public static String getDecimalLocaleFormatString(Decimal value, Integer scale) {
        String result = '';
        Decimal temp = value.setScale(scale);
        String fraction = String.valueOf(temp).substringAfter('.');
        result = (value < 0 ? (Decimal.valueOf(value.intValue()) - 0.1) : (Decimal.valueOf(value.intValue()) + 0.1)).format();
        result = result.substring(0, scale == 0 ? result.length() - 2 : result.length() - 1) + fraction;
        if (value < 0) {
            result = '(' + result.remove('-') + ')';
        }
        return value == 0 ? '0.' + fraction : result;
    }

    @AuraEnabled(Cacheable=true)
    public static List<Project_Task__c> getProjectTasks(String projectId) {
        List<Project_Task__c> result = new List<Project_Task__c>();
        try {
            result = FinancialSuiteUtils.queryProjectTasks(new Set<Id>{projectId});
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        return result;
    }

    public static List<Project_Task__c> queryProjectTasks(Set<Id> projectIds) {
        //Prepare SOQL Query to query Project Tasks with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id', 'Name', 'Project__c'
        };

        String queryCondition =
            'Project__c IN :projectIds AND Display_in_Time_Card__c = true ORDER BY Sort_Order__c ASC';

        SOQLBuilder theQuery = new SOQLBuilder(Project_Task__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        //============================================================================
        return (List<Project_Task__c>) Database.query(theQuery.toSOQL());
    }

    public static String getDefaultPostingStatus(Schema.SObjectField fieldToken) {
        String defaultValue = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;

        for (Schema.PicklistEntry pickListEntry : fieldToken.getDescribe().getPicklistValues()) {
            if (pickListEntry.isDefaultValue() && pickListEntry.getValue() != AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED) {
                defaultValue = pickListEntry.getValue();
                break;
            }
        }
        return defaultValue;
    }

    public static Task setTask(String recordId, String subject, String description) {
        return setTask(recordId, NULL, NULL, subject, description, NULL);
    }

    public static Task setTask(String recordId, String status, String priority, String subject, String description, String ownerId) {
        return setTask(recordId, status, priority, subject, description, ownerId, NULL);
    }

    public static Task setTask(String recordId, String status, String priority, String subject, String description, String ownerId, String ajrId) {
        Task theTask = new Task();
        theTask.WhatId = recordId;
        theTask.OwnerId = String.isBlank(ownerId) ? UserInfo.getUserId() : ownerId;
        theTask.ActivityDate = System.today();
        theTask.Status = String.isBlank(status) ? 'Completed' : status;
        theTask.Priority = String.isBlank(priority) ? 'Normal' : priority;
        theTask.Subject = subject;
        theTask.Description = description;
        theTask.Automated_Job_Result__c = ajrId;
        return theTask;
    }

    public static Boolean isNotNullAndNotEmpty(List<SObject> collection) {
        return collection != NULL && !collection.isEmpty();
    }

    public static String getRedirectToSObjectURL(Id recordId, SObjectType soType, Boolean toEdit) {
        String result = '';
        String currentUIMode = UserInfo.getUiThemeDisplayed();
        switch on currentUIMode {
            when 'Theme4d', 'Theme4t' {
                result += '/lightning/r/' + soType + '/' + recordId;
                if (toEdit) {
                    result += '/edit?backgroundContext=/lightning/r/' + soType + '/' + recordId + '/view';
                }
                else {
                    result += '/view';
                }
            }
            when 'Theme4u' {
                result += '/lightning/r/' + soType + '/' + recordId + '/view';
            }
            when else {
                result += '/' + recordId;
                if (toEdit) {
                    result += '/e?retURL=/' + recordId;
                }
            }
        }
        return result;
    }

    public static DateRange getDateRange(List<SObject> records, SObjectField dateFieldToken) {
        DateRange result = new DateRange(NULL, NULL);
        if (records != NULL && !records.isEmpty() && dateFieldToken != NULL) {
            List<Date> allDates = new List<Date>();
            for (SObject record : records) {
                Date d = (Date) record.get(dateFieldToken);
                if (d != NULL) {
                    allDates.add(d);
                }
            }
            allDates.sort();
            if (!allDates.isEmpty()) {
                result = new DateRange(allDates.get(0), allDates.get(allDates.size() - 1));
            }
        }
        return result;
    }

    public with sharing class DateRange {
        public Date startDate;
        public Date endDate;

        public DateRange(Date startDate, Date endDate) {
            this.startDate = startDate;
            this.endDate = endDate;
        }
    }

    public static String trunc(String s, Integer chars) {
        return String.isEmpty(s) ? s : s.left(chars);
    }

    /**
     * Takes a date string and pads month and day with a '0' if only 1 digit.
     * Example 1: 5/3/2021 => 05/03/2021
     * Example 2: 14.8.2021 => 14.08.2021
     */
    public static String padDayAndMonth(String unpaddedDate) {
        String paddedDate = '';
        for (String s : unpaddedDate.splitByCharacterType()) {
            if (s.isNumeric() && s.length() == 1) {
                s = s.leftPad(2, '0');
            }
            paddedDate += s;
        }
        return paddedDate;
    }

    /**
     * Returns the character used as a separator component of the input date string.
     * Example 1: 5/21/2021 => '/'
     * Example 2: 21.5.2021 => '.'
     * Example 3: 2021,5,21 => ','
     * Example 4: 5212021   => '' (default)
     */
    public static String getDateSeparator(String d) {
        for (String s : d.splitByCharacterType()) {
            if (!s.isNumeric()) {
                return s;
            }
        }
        return '';
    }

    public static SObjectField getSObjectFieldToken(SObjectType soType, String fieldApiName) {
        return soType.getDescribe().fields.getMap().get(fieldApiName);
    }

    private static Map<Schema.SObjectField, List<Schema.PicklistEntry>> picklistEntriesBySObjectFields = new Map<SObjectField, List<PicklistEntry>>();

    public static Map<Schema.SObjectField, List<Schema.PicklistEntry>> fetchPicklistEntriesBySObjectFields(List<Schema.SObjectField> sObjectFields) {
        for (Schema.SObjectField field : sObjectFields) {
            if (!picklistEntriesBySObjectFields.containsKey(field)) {
                picklistEntriesBySObjectFields.put(field, field.getDescribe().getPicklistValues());
            }
        }
        return picklistEntriesBySObjectFields;
    }

    public static Map<Schema.SObjectField, List<String>> fetchPicklistValuesBySObjectFields(List<Schema.SObjectField> sObjectFields) {
        Map<Schema.SObjectField, List<Schema.PicklistEntry>> picklistEntriesBySObjectFields = fetchPicklistEntriesBySObjectFields(sObjectFields);

        Map<Schema.SObjectField, List<String>> picklistValuesBySObjectFields = new Map<SObjectField, List<String>>();
        for (Schema.SObjectField field : picklistEntriesBySObjectFields.keySet()) {
            if (picklistEntriesBySObjectFields.get(field) != null) {
                List<String> values = new List<String>();
                for (Schema.PicklistEntry entry : picklistEntriesBySObjectFields.get(field)) {
                    values.add(entry.value);
                }
                picklistValuesBySObjectFields.put(field, values);
            }
        }
        return picklistValuesBySObjectFields;
    }

    public static Map<Schema.SObjectField, Set<String>> fetchUniquePicklistValuesBySObjectFields(List<Schema.SObjectField> sObjectFields) {
        Map<Schema.SObjectField, List<String>> picklistEntriesBySObjectFields = fetchPicklistValuesBySObjectFields(sObjectFields);

        Map<Schema.SObjectField, Set<String>> uniquePicklistValuesBySObjectFields = new Map<SObjectField, Set<String>>();
        for (Schema.SObjectField field : picklistEntriesBySObjectFields.keySet()) {
            if (picklistEntriesBySObjectFields.get(field) != null) {
                uniquePicklistValuesBySObjectFields.put(field, new Set<String>(picklistEntriesBySObjectFields.get(field)));
            }
        }
        return uniquePicklistValuesBySObjectFields;
    }

    public static Decimal stringToDecimal(String s) {
        Decimal d;
        try {
            d = String.isBlank(s) ? d : Decimal.valueOf(s);
        } catch (TypeException e) {
            // not a number
        }
        return d;
    }

    public static Date getNextRecurringDate(Date prevDate, String frequency) {
        if (prevDate == null || frequency == null) {
            return advanceDateByMonths(prevDate, 1);
        }
        switch on frequency.toLowerCase().replace('-', '') {
            when 'weekly' {
                return prevDate.addDays(7);
            }
            when 'biweekly' {
                return prevDate.addDays(14);
            }
            when 'monthly' {
                return advanceDateByMonths(prevDate, 1);
            }
            when 'quarterly' {
                return advanceDateByMonths(prevDate, 3);
            }
            when 'semiannual' {
                return advanceDateByMonths(prevDate, 6);
            }
            when 'annual' {
                return advanceDateByMonths(prevDate, 12);
            }
            when else {
                return advanceDateByMonths(prevDate, 1);
            }
        }
    }

    private static Date advanceDateByMonths(Date prevDate, Integer months) {
        Integer year = prevDate.year();
        Integer month = prevDate.month();
        Integer day = prevDate.day();
        Date nextDate;

        if ((month == 1 || month == 3 || month == 5 || month == 7 || month == 10 || month == 12) && day == 31) {
            nextDate = getLastDayOfMonth(prevDate.addMonths(months));
        }
        else if ((month == 2 && day == 28) || (month == 2 && Date.isLeapYear(year) && day == 29)) {
            nextDate = getLastDayOfMonth(prevDate.addMonths(months));
        }
        else if ((month == 4 || month == 6 || month == 8 || month == 9 || month == 11) && day == 30) {
            nextDate = getLastDayOfMonth(prevDate.addMonths(months));
        }
        else {
            nextDate = prevDate.addMonths(months);
        }

        return nextDate;
    }

    private static Date getLastDayOfMonth(Date d) {
        return Date.newInstance(d.year(), d.month(), Date.daysInMonth(d.year(), d.month()));
    }

    public static Object fetchValue(SObject record, List<SObjectField> fields) {
        Object value = null;
        for (Integer index = 0; index < fields.size(); index++) {
            SObjectField field = fields[index];
            if (record != null) {
                if (index < fields.size() - 1) {
                    record = record.getSObject(field);
                } else {
                    value = record.get(field);
                }
            } else {
                value = null;
                break;
            }
        }

        return value;
    }

    // adds a character to the end of the provided string if it 
    // does not already end in a non-alphanumeric character.
    public static String punctuate(String s) {
        String suffix = s.substring(s.length() - 1);
        // add a period if the last character is alphanumeric or a closing character
        if (suffix.isAlphanumeric() || suffix == ')' || suffix == ']' || suffix == '\'' || suffix == '"' || suffix == '>') {
            return s + '.';
        }
        return s;
    }
}