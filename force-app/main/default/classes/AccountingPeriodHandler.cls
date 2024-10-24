public without sharing class AccountingPeriodHandler {
    public class AccountingPeriodException extends Exception {}

    public static final String ACCOUNTING_PERIOD_DOES_NOT_EXIST = Label.ERR_ACCOUNTING_PERIOD_DOES_NOT_EXIST;
    private static AccountingPeriodHandler instance;

    private Map<String, Accounting_Period__c> allAcctPeriodsByName;
    private Map<Integer, Accounting_Period__c> allAcctPeriodsBySerialNumber;
    private Map<Id, Accounting_Period__c> allAcctPeriodsById;
    private Map<Id, Integer> allSerialNumbersByAcctPeriodId;
    private Set<sObjectType> arSubLedgerTypes;
    private Set<sObjectType> apSubLedgerTypes;

    private AccountingPeriodHandler() {
        init();
    }

    public static AccountingPeriodHandler getInstance() {
        if (instance == NULL) {
            instance = new AccountingPeriodHandler();
        }
        return instance;
    }

    public static void reset() {
        instance = NULL;
    }

    private void init() {
        allAcctPeriodsByName = new Map<String, Accounting_Period__c>();
        allAcctPeriodsBySerialNumber = new Map<Integer, Accounting_Period__c>();
        allAcctPeriodsById = new Map<Id, Accounting_Period__c>();
        allSerialNumbersByAcctPeriodId = new Map<Id, Integer>();

        //SFTCLS:  set sub ledger type collections
        arSubLedgerTypes = AccountingPeriod.arSubLedgerTypes;
        apSubLedgerTypes = AccountingPeriod.apSubLedgerTypes;

        try {
            List<Accounting_Period__c> accountingPeriods = DomainUtils.getAllAccountingPeriods();

            Integer serialNumber = 0;
            for (Accounting_Period__c accountingPeriod : accountingPeriods) {
                allAcctPeriodsById.put(accountingPeriod.Id, accountingPeriod);
                allAcctPeriodsByName.put(accountingPeriod.Name, accountingPeriod);
                allAcctPeriodsBySerialNumber.put(serialNumber, accountingPeriod);
                allSerialNumbersByAcctPeriodId.put(accountingPeriod.Id, serialNumber);
                serialNumber++;
            }
        }
        catch (Exception ex) {
            ex.setMessage(Label.ERR_PERIOD_HANDLER_INITIALIZATION + ': ' + ex.getMessage());
            throw ex;
        }
    }

    private AccountingPeriod.SubLedgerType getSubLedgerType(sObjectType sObjType){
        AccountingPeriod.SubLedgerType sLT;

        //AP 
        if(arSubLedgerTypes.contains(sObjType)){
            sLT = AccountingPeriod.SubLedgerType.AR;
        } 
        //AR
        else if(apSubLedgerTypes.contains(sObjType)){
            sLT = AccountingPeriod.SubLedgerType.AP;
        }
        return sLT;
    }

    public Integer compareAccountingPeriods(Id acctPeriod1, Id acctPeriod2) {
        Integer acctPeriodSerialNumber1 = getSerialNumberById(acctPeriod1);
        Integer acctPeriodSerialNumber2 = getSerialNumberById(acctPeriod2);

        if (acctPeriodSerialNumber1 > acctPeriodSerialNumber2) {
            return 1;
        }
        else if (acctPeriodSerialNumber1 < acctPeriodSerialNumber2) {
            return -1;
        }
        else {
            return 0;
        }
    }
    
    public Accounting_Period__c getLastClosedOrArchivedAccountingPeriod() {
        for (Integer i = (allAcctPeriodsBySerialNumber.size() - 1); i >= 0; i--) {
            if (allAcctPeriodsBySerialNumber.get(i).Status__c == AccountingPeriodActions.CLOSED_STATUS
                    || allAcctPeriodsBySerialNumber.get(i).Status__c == AccountingPeriodActions.OPEN_INTERIM_STATUS
                    || allAcctPeriodsBySerialNumber.get(i).Status__c == AccountingPeriodActions.ARCHIVED_STATUS
                    || allAcctPeriodsBySerialNumber.get(i).Status__c == AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS) {

                return allAcctPeriodsBySerialNumber.get(i);
            }
        }
        return NULL;
    }

    
    public Boolean isConsideredOpen(Accounting_Period__c period) {
        if (period != NULL && period.Id != NULL) {
            return isConsideredOpen(period.Id, NULL);
        }
        else {
            return false;
        }
    }

    public Boolean isConsideredOpen(Id periodId) {
        if (periodId != NULL) {
            return isConsideredOpen(periodId, NULL);
        }
        else {
            return false;
        }
    }

    public Boolean isConsideredOpen(Id periodId, sObjectType sObjType){
        Boolean isOpen = false;

        if(periodId == null){
            return isOpen;
        }
        isOpen = openPeriodExists(periodId);

        if (sObjType == NULL) {
            isOpen = isOpen;
        }
        //SFTCLS: check based on Status__c and Type
        else if (isOpen && sObjType != null) {
            isOpen = true;
            Accounting_Period__c period = allAcctPeriodsById.get(periodId);
            AccountingPeriod.SubLedgerType sLT = getSubLedgerType(sObjType);
            switch on sLT {
                when AP {
                    isOpen = period.Close_AP__c ? false : true;
                }
                when AR {
                    isOpen = period.Close_AR__c ? false : true;
                }
             }
        } 
        return isOpen;
    }

    public Boolean isConsideredOpenForReporting(Id periodId) {
        if (periodId != NULL ) {
            Accounting_Period__c period = allAcctPeriodsById.get(periodId);
            Set<String> validStatuses = new Set<String>{
                AccountingPeriodActions.OPEN_STATUS,
                AccountingPeriodActions.CLOSE_INTERIM_STATUS
            };

            return validStatuses.contains(period.Status__c);
        }
        else {
            return false;
        }
    }

    public Boolean isConsideredClosed(Accounting_Period__c period) {
        if (period != NULL && period.Id != NULL) {
            return isConsideredClosed(period.Id, NULL);
        }
        else {
            return false;
        }
    }

    public Boolean isConsideredClosed(Id periodId) {
        if (periodId != NULL) {
            return isConsideredClosed(periodId, NULL);
        }
        else {
            return false;
        }
    }

    public Boolean isConsideredClosed(Id periodId, sObjectType sObjType){
        Boolean isClosed = false;
       
        if(periodId == null){
            return isClosed;
        }
                
        if (sObjType == NULL) {
            isClosed = closedPeriodExists(periodId);
        }
        //SFTCLS: check based on Status__c and Type
        else if (sObjType != null) {
            isClosed = closedPeriodExists(periodId);
            Accounting_Period__c period = allAcctPeriodsById.get(periodId);
            AccountingPeriod.SubLedgerType sLT = getSubLedgerType(sObjType);
            switch on sLT {
                when AP {
                    isClosed = isClosed || period.Close_AP__c ? true : false;
                }
                when AR {
                    isClosed = isClosed || period.Close_AR__c ? true : false;
                }
             }
        } 
        return isClosed;
    }

    private Boolean openPeriodExists(Id periodId){
        Accounting_Period__c period = allAcctPeriodsById.get(periodId);
        Set<String> validStatuses = new Set<String>{
            AccountingPeriodActions.OPEN_STATUS
        };

        return validStatuses.contains(period.Status__c);
    }

    private Boolean closedPeriodExists(Id periodId){
        Accounting_Period__c period = allAcctPeriodsById.get(periodId);
            Set<String> validStatuses = new Set<String>{
                AccountingPeriodActions.CLOSED_STATUS,
                AccountingPeriodActions.CLOSE_INTERIM_STATUS,
                AccountingPeriodActions.OPEN_INTERIM_STATUS,
                AccountingPeriodActions.ARCHIVED_STATUS,
                AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS
            };

            return validStatuses.contains(period.Status__c);
    }

    public Accounting_Period__c getMostRecentAccountingPeriodFromCollection(List<Accounting_Period__c> periods) {
        Set<Id> periodIds = new Map<Id, Accounting_Period__c>(periods).keySet();
        return getMostRecentAccountingPeriodFromCollection(periodIds);
    }

    public Accounting_Period__c getMostRecentAccountingPeriodFromCollection(Set<Id> periodIds) {
        List<Integer> orderedSerialNumberList = getSerialNumbersById(periodIds);
        Integer mostRecentSerialNumber = orderedSerialNumberList.get(orderedSerialNumberList.size() - 1);

        return allAcctPeriodsBySerialNumber.get(mostRecentSerialNumber);
    }

    public Accounting_Period__c getMostRecentOpenAccPeriodFromCollectionOrFirstOpen(Set<Id> periodIds) {
        return getMostRecentOpenAccPeriodFromCollectionOrFirstOpen(periodIds, NULL);
    }

    public Accounting_Period__c getMostRecentOpenAccPeriodFromCollectionOrFirstOpen(Set<Id> periodIds, sObjectType sobjType) {
        
        Accounting_Period__c result;
        result = getMostRecentAccountingPeriodFromCollection(periodIds);
        if (!isConsideredOpen(result.Id, sObjType)) {
            result = getFirstOpenedPeriod(sobjType);
        }
        return result;
    }

    public Accounting_Period__c getMostEarlierAccountingPeriodFromCollection(List<Accounting_Period__c> periods) {
        Set<Id> periodIds = new Map<Id, Accounting_Period__c>(periods).keySet();
        return getMostEarlierAccountingPeriodFromCollection(periodIds);
    }

    public Accounting_Period__c getMostEarlierAccountingPeriodFromCollection(Set<Id> periodIds) {
        List<Integer> orderedSerialNumberList = getSerialNumbersById(periodIds);
        Integer mostEarlierSerialNumber = orderedSerialNumberList.get(0);

        return allAcctPeriodsBySerialNumber.get(mostEarlierSerialNumber);
    }

    public List<Accounting_Period__c> getAllAccountingPeriods() {
        return getAllAccountingPeriods(NULL, SOQLBuilder.SortOrder.ASCENDING);
    }

    public List<Accounting_Period__c> getAllAccountingPeriods(Set<String> validStatuses) {
        return getAllAccountingPeriods(validStatuses, SOQLBuilder.SortOrder.ASCENDING);
    }

    public List<Accounting_Period__c> getAllAccountingPeriods(SOQLBuilder.SortOrder sortOrder) {
        return getAllAccountingPeriods(NULL, sortOrder);
    }

    public List<Accounting_Period__c> getAllAccountingPeriods(Set<String> validStatuses, SOQLBuilder.SortOrder sortOrder){
         return getAllAccountingPeriods(validStatuses, sortOrder, null); 
    }

    public List<Accounting_Period__c> getAllAccountingPeriods(Set<String> validStatuses, SOQLBuilder.SortOrder sortOrder, sObjectType sObjType) {
        
        List<Accounting_Period__c> result = new List<Accounting_Period__c>();
        if (sortOrder == NULL || sortOrder == SOQLBuilder.SortOrder.ASCENDING) {
            result = allAcctPeriodsByName.values();
        }
        else {
            List<Accounting_Period__c> ascList = allAcctPeriodsByName.values();
            List<Accounting_Period__c> descList = new List<Accounting_Period__c>();
            for (Integer i = ascList.size() - 1; i >= 0; i--) {
                descList.add(ascList[i]);
            }

            result = descList;
        }

        if(validStatuses != NULL && !validStatuses.isEmpty()){
            
            List<Accounting_Period__c> validPeriods = new List<Accounting_Period__c>();
            for (Accounting_Period__c period : result) {

                //if no sObjType is passed in then this method is not being used by a part of the application that respects the soft close status
                if(sObjType == null && validStatuses.contains(period.Status__c)){
                    validPeriods.add(period);
                    continue;
                }
                
                //if open or closed then also check the soft close status 
                if (validStatuses.contains(AccountingPeriodActions.OPEN_STATUS) && isConsideredOpen(period.Id, sObjType)) {
                    validPeriods.add(period);
                }else if(validStatuses.contains(AccountingPeriodActions.CLOSED_STATUS) && isConsideredClosed(period.Id, sObjType)){
                    validPeriods.add(period);
                }else if(validStatuses.contains(period.Status__c)){
                    validPeriods.add(period);
                }
            }
            
            result = validPeriods;
        }

        return result;
    }

    public List<Accounting_Period__c> getAccountingPeriodsByYears(Set<Integer> years) {
        return getAccountingPeriodsByYears(years, SOQLBuilder.SortOrder.ASCENDING);
    }

    public List<Accounting_Period__c> getAccountingPeriodsByYears(Set<Integer> years, SOQLBuilder.SortOrder sortOrder) {
        List<Accounting_Period__c> result = new List<Accounting_Period__c>();
        for (Accounting_Period__c accountingPeriod : getAllAccountingPeriods(sortOrder)) {
            if (years.contains(accountingPeriod.Start_Date__c.year())
                    || years.contains(accountingPeriod.End_Date__c.year())) {

                result.add(accountingPeriod);
            }
        }
        return result;
    }

    public Accounting_Period__c getAccountingPeriodByName(String name) {
        return allAcctPeriodsByName.get(name);
    }

    public List<Accounting_Period__c> getAccountingPeriodsByName(Set<String> periodNames) {
        List<Accounting_Period__c> result = new List<Accounting_Period__c>();
        for (String name : periodNames) {
            Accounting_Period__c existedPeriod = getAccountingPeriodByName(name);
            if (existedPeriod != NULL) {
                result.add(existedPeriod);
            }
        }
        return result;
    }

    public List<Accounting_Period__c> filterByName(List<Accounting_Period__c> periods, Set<String> excludeNames) {
        List<Accounting_Period__c> result = new List<Accounting_Period__c>();

        if (excludeNames != NULL && !excludeNames.isEmpty()) {
            List<Accounting_Period__c> filteredPeriods = new List<Accounting_Period__c>();
            for (Accounting_Period__c period : periods) {
                if (!excludeNames.contains(period.Name)) {
                    filteredPeriods.add(period);
                }
            }
            result = filteredPeriods;
        }

        return result;
    }

    public Accounting_Period__c getAccountingPeriodById(Id acctPeriodId) {
        return allAcctPeriodsById.get(acctPeriodId);
    }

    public List<Accounting_Period__c> getAccountingPeriodsById(Set<Id> accountingPeriodIds) {
        List<Accounting_Period__c> result = new List<Accounting_Period__c>();
        for (Id accountingPeriodId : accountingPeriodIds) {
            result.add(allAcctPeriodsById.get(accountingPeriodId));
        }
        return result;
    }

    public Accounting_Period__c getAccountingPeriodByStartDate(Date startDate) {
        Accounting_Period__c result;
        for (Accounting_Period__c accountingPeriod : allAcctPeriodsBySerialNumber.values()) {
            if (accountingPeriod.Start_Date__c == startDate) {
                result = accountingPeriod;
                break;
            }
        }
        return result;
    }

    public Accounting_Period__c getAccountingPeriodByEndDate(Date endDate) {
        Accounting_Period__c result;
        for (Accounting_Period__c accountingPeriod : allAcctPeriodsBySerialNumber.values()) {
            if (accountingPeriod.End_Date__c == endDate) {
                result = accountingPeriod;
                break;
            }
        }
        return result;
    }

    public Accounting_Period__c getAccountingPeriodByDate(Date aDate) {
        Accounting_Period__c result;
        for (Accounting_Period__c accountingPeriod : allAcctPeriodsByName.values()) {
            if (accountingPeriod.Start_Date__c <= aDate && accountingPeriod.End_Date__c >= aDate) {
                result = accountingPeriod;
                break;
            }
        }
        return result;
    }

    public Accounting_Period__c getAccountingPeriodByDateAndStatus(Date aDate, String validStatus) {
        return getAccountingPeriodByDateAndStatus(aDate, new Set<String>{validStatus}, NULL);
    }

    public Accounting_Period__c getAccountingPeriodByDateAndStatus(Date aDate, Set<String> validStatuses) {
        return getAccountingPeriodByDateAndStatus(aDate, validStatuses, NULL);
    }

    public Accounting_Period__c getAccountingPeriodByDateAndStatus(Date aDate, Set<String> validStatuses, sObjectType sObjType) {
        Accounting_Period__c result;

        if (validStatuses == NULL) {
            validStatuses = new Set<String>();
        }

        for (Accounting_Period__c accountingPeriod : allAcctPeriodsByName.values()) {
            if (accountingPeriod.Start_Date__c <= aDate 
                && accountingPeriod.End_Date__c >= aDate 
                && validStatuses.contains(accountingPeriod.Status__c)) {

                //use isConsidered methods to take into account the Soft Close checkboxes for subledger if the sObjType is supplied
                if(sObjType != NULL &&
                    (validStatuses.contains(AccountingPeriodActions.OPEN_STATUS) && isConsideredClosed(accountingPeriod.Id, sObjType)) ||
                    (validStatuses.contains(AccountingPeriodActions.CLOSED_STATUS) && isConsideredOpen(accountingPeriod.Id, sObjType))){
                    break;
                }
                result = accountingPeriod;
                break;
            }
        }
        return result;

    }

    public List<Accounting_Period__c> getPriorAccountingPeriodsForThisYear(Id periodId, Boolean inclusive) {
        return  getPriorAccountingPeriodsForThisYear(getAccountingPeriodById(periodId), inclusive);
    }

    public List<Accounting_Period__c> getPriorAccountingPeriodsForThisYear(Accounting_Period__c acctPeriod, Boolean inclusive) {
        return getPriorAccountingPeriodsForThisYear(acctPeriod, NULL, inclusive);
    }

    public List<Accounting_Period__c> getPriorAccountingPeriodsForThisYear(Accounting_Period__c acctPeriod, Set<String> validStatuses, Boolean inclusive) {
        List<Accounting_Period__c> result = new List<Accounting_Period__c>();
        String yearPartOfPeriodName = acctPeriod.Name.substring(0, 4);
        String monthPartOfPeriodName = acctPeriod.Name.substring(5, 7);
        for (Accounting_Period__c eachPriorPeriod : getPreviousAccountingPeriods(acctPeriod, validStatuses, inclusive)) {
            if (eachPriorPeriod.Name.startsWith(yearPartOfPeriodName)
                    && eachPriorPeriod.Name.substring(5, 7) <= monthPartOfPeriodName) {

                result.add(eachPriorPeriod);
            }
        }
        result.sort();
        return result;
    }

    public List<Accounting_Period__c> getPreviousAccountingPeriods(Date currentDate) {
        return getPreviousAccountingPeriods(currentDate, NULL);
    }

    public List<Accounting_Period__c> getPreviousAccountingPeriods(Accounting_Period__c acctPeriod) {
        return getPreviousAccountingPeriods(acctPeriod, NULL, false);
    }

    public List<Accounting_Period__c> getPreviousAccountingPeriods(Date currentDate, Set<String> validStatuses) {
        Accounting_Period__c currentAccountingPeriod = getAccountingPeriodByDate(currentDate);
        return getPreviousAccountingPeriods(currentAccountingPeriod, validStatuses, false);
    }

    public List<Accounting_Period__c> getPreviousAccountingPeriods(Id periodId, Set<String> validStatuses) {
        Accounting_Period__c acctPeriod = getAccountingPeriodById(periodId);
        return getPreviousAccountingPeriods(acctPeriod, validStatuses, false);
    }

    public List<Accounting_Period__c> getPreviousAccountingPeriods( Accounting_Period__c acctPeriod,
                                                                    Set<String> validStatuses) {

        return getPreviousAccountingPeriods(acctPeriod, validStatuses, false);
    }

    public List<Accounting_Period__c> getPreviousAccountingPeriods( Accounting_Period__c acctPeriod,
                                                                    Set<String> validStatuses,
                                                                    Boolean includeCurrent) {

        List<Accounting_Period__c> result = new List<Accounting_Period__c>();
        if (acctPeriod != NULL) {
            Integer currentPeriodSerialNumber = getSerialNumberById(acctPeriod.Id);
            Integer previousPeriodSerialNumber = 0;
            while (previousPeriodSerialNumber < currentPeriodSerialNumber) {
                result.add(allAcctPeriodsBySerialNumber.get(previousPeriodSerialNumber));
                previousPeriodSerialNumber++;
            }

            if (includeCurrent) {
                result.add(allAcctPeriodsBySerialNumber.get(currentPeriodSerialNumber));
            }

            if (validStatuses != NULL) {
                List<Accounting_Period__c> validAcctPeriods = new List<Accounting_Period__c>();
                for (Accounting_Period__c eachAcctPeriod : result) {
                    if (validStatuses.contains(eachAcctPeriod.Status__c)) {
                        validAcctPeriods.add(eachAcctPeriod);
                    }
                }

                result = validAcctPeriods;
            }
        }

        return result;
    }

    public Accounting_Period__c getPreviousAccountingPeriod(String name) {
        return getPreviousAccountingPeriod(getAccountingPeriodByName(name));
    }

    public Accounting_Period__c getPreviousAccountingPeriod(Accounting_Period__c acctPeriod) {
        return getPreviousAccountingPeriod(acctPeriod.Id);
    }

    public Accounting_Period__c getPreviousAccountingPeriod(Id acctPeriodId) {
        return getAccountingPeriodByOffset(acctPeriodId, -1);
    }

    public Accounting_Period__c getNextAccountingPeriod(String name) {
        return getNextAccountingPeriod(getAccountingPeriodByName(name));
    }

    public Accounting_Period__c getNextAccountingPeriod(Accounting_Period__c acctPeriod) {
        return getNextAccountingPeriod(acctPeriod.Id);
    }

    public Accounting_Period__c getNextAccountingPeriod(Id acctPeriodId) {
        return getAccountingPeriodByOffset(acctPeriodId, 1);
    }

    public List<Accounting_Period__c> getNextAccountingPeriods(Accounting_Period__c currentPeriod, Set<String> validStatuses) {
        return getNextAccountingPeriods(currentPeriod, validStatuses, null);
    }

    public List<Accounting_Period__c> getNextAccountingPeriods(Accounting_Period__c currentPeriod, Set<String> validStatuses, sObjectType sobjType) {
       
        List<Accounting_Period__c> result = new List<Accounting_Period__c>();
        Integer currentPeriodSerialNumber = getSerialNumberById(currentPeriod.Id);
        Integer lastPeriodSerialnumber = allAcctPeriodsBySerialNumber.size() - 1;
        if (currentPeriodSerialNumber < lastPeriodSerialnumber) {
            for (Integer i = currentPeriodSerialNumber + 1; i <= lastPeriodSerialnumber; i++) {
                result.add(allAcctPeriodsBySerialNumber.get(i));
            }
        }

        List<Accounting_Period__c> validPeriods = new List<Accounting_Period__c>();
        
        if(validStatuses != NULL && !validStatuses.isEmpty()){

            for (Accounting_Period__c period : result) {
                
                if (validStatuses.contains(AccountingPeriodActions.OPEN_STATUS) && isConsideredOpen(period.Id, sObjType)) 
                {
                    validPeriods.add(period);
                }

                if(validStatuses.contains(AccountingPeriodActions.CLOSED_STATUS) && isConsideredClosed(period.Id, sObjType))
                {
                    validPeriods.add(period);
                }
            }
            
            result = validPeriods;
        }
        
        return result;
    }

    public Accounting_Period__c getAccountingPeriodByOffset(String name, Integer offset) {
        return getAccountingPeriodByOffset(getAccountingPeriodByName(name), offset);
    }

    public Accounting_Period__c getAccountingPeriodByOffset(Accounting_Period__c currentAcctPeriod, Integer offset) {
        return getAccountingPeriodByOffset(currentAcctPeriod.Id, offset);
    }

    public Accounting_Period__c getAccountingPeriodByOffset(Id currentAcctPeriodId, Integer offset) {
        if (offset == NULL) {
            offset = 0;
        }
        Accounting_Period__c result;
        Integer thisAccountingPeriodSerialNumber = getSerialNumberById(currentAcctPeriodId);
        result = allAcctPeriodsBySerialNumber.get(thisAccountingPeriodSerialNumber + offset);

        if (result == NULL) {
            result = getFakePeriodFromOffset(currentAcctPeriodId, offset);
        }
        return result;
    }

    public List<Accounting_Period__c> getAccountingPeriodsFromRange(String startPeriodName, Integer numberOfPeriods) {
        return getAccountingPeriodsFromRange(getAccountingPeriodByName(startPeriodName), numberOfPeriods);
    }

    public List<Accounting_Period__c> getAccountingPeriodsFromRange(Accounting_Period__c startPeriod,
                                                                    Integer numberOfPeriods) {

        return getAccountingPeriodsFromRange(startPeriod.Id, numberOfPeriods);
    }

    public List<Accounting_Period__c> getAccountingPeriodsFromRange(Id startPeriodId, Integer numberOfPeriods) {
        List<Accounting_Period__c> result = new List<Accounting_Period__c>();
        Integer startPeriodSerialNumber = getSerialNumberById(startPeriodId);

        for (Integer i = startPeriodSerialNumber; i <= (startPeriodSerialNumber + (numberOfPeriods - 1)); i++) {
            if (allAcctPeriodsBySerialNumber.get(i) != NULL) {
                result.add(allAcctPeriodsBySerialNumber.get(i));
            }
        }

        return result;
    }

    public List<Accounting_Period__c> getAccountingPeriodsByDateRangeAndStatus(Date startDate, Date endDate, String status) {
        List<Accounting_Period__c> result = new List<Accounting_Period__c>();
        for (Accounting_Period__c ap : allAcctPeriodsByName.values()) {
            if (ap.Status__c == status
                    && ((ap.Start_Date__c <= startDate && ap.End_Date__C >= startDate) || (ap.Start_Date__c >= startDate && ap.Start_Date__c <= endDate))) {

                result.add(ap);
            }
        }

        return result;
    }

    public Boolean isPastOpenOrInProgressPeriodExists(Accounting_Period__c currentPeriod) {
        Boolean result = true;
        List<Accounting_Period__c> previousPeriodsByStatus =
            getPreviousAccountingPeriods(
                currentPeriod,
                new Set<String>{
                    AccountingPeriodActions.OPEN_STATUS,
                    AccountingPeriodActions.CLOSE_INTERIM_STATUS,
                    AccountingPeriodActions.OPEN_INTERIM_STATUS
                }
            );

        if (previousPeriodsByStatus.isEmpty()) {
            result = false;
        }
        return result;
    }

    public Boolean isFutureClosedPeriodExists(Accounting_Period__c currentPeriod) {
        Boolean result = true;
        List<Accounting_Period__c> futureClosedPeriods =
            getNextAccountingPeriods(currentPeriod, new Set<String>{AccountingPeriodActions.CLOSED_STATUS});

        if (futureClosedPeriods.isEmpty()) {
            result = false;
        }
        return result;
    }

    public Integer countAccountingPeriodsInRange(Id startPeriodId, Id endPeriodId) {
        return getAccountingPeriodsFromRange(startPeriodId, endPeriodId).size();
    }

    public List<Accounting_Period__c> getAccountingPeriodsFromRange(Id startPeriodId, Id endPeriodId) {
        return
            getAccountingPeriodsFromRange(
                getAccountingPeriodById(startPeriodId),
                getAccountingPeriodById(endPeriodId)
            );
    }

    public List<Accounting_Period__c> getAccountingPeriodsFromRange(Accounting_Period__c startPeriod,
                                                                    Accounting_Period__c endPeriod) {

        List<Accounting_Period__c> result = new List<Accounting_Period__c>();
        Integer startPeriodSerialNumber = getSerialNumberById(startPeriod.Id);
        Integer endPeriodSerialNumber = getSerialNumberById(endPeriod.Id);

        for (Integer i = startPeriodSerialNumber; i <= endPeriodSerialNumber; i++) {
            result.add(allAcctPeriodsBySerialNumber.get(i));
        }

        return result;
    }

    public List<Accounting_Period__c> getAccountingPeriodsByFinancialReportColumns(
        Id startPeriodId,
        List<Financial_Report_Column__c> frColumns) {

        List<Accounting_Period__c> result = new List<Accounting_Period__c>();
        if (frColumns.isEmpty()) {
            result.add(getAccountingPeriodById(startPeriodId));
        }
        for (Financial_Report_Column__c frColumn : frColumns) {
            if (frColumn.Type__c == FinancialReportColumnActions.FRC_TYPE_CURRENT_PERIOD || frColumn.Type__c == FinancialReportColumnActions.FRC_TYPE_YEAR_TO_DATE) {
                result.add(getAccountingPeriodByOffset(startPeriodId, (Integer) frColumn.Offset__c));
            }
        }
        return result;
    }

    public String toString(Accounting_Period__c accountingPeriod) {
        return accountingPeriod.Name;
    }

    public List<String> toString(List<Accounting_Period__c> accountingPeriods) {
        List<String> result = new List<String>();
        for (Accounting_Period__c ap : accountingPeriods) {
            result.add(ap.Name);
        }
        return result;
    }

    private List<Integer> getSerialNumbersById(Set<Id> periodIds) {
        List<Integer> serialNumberList = new List<Integer>();
        for (Id periodId : periodIds) {
            serialNumberList.add(allSerialNumbersByAcctPeriodId.get(periodId));
        }

        serialNumberList.sort();

        return serialNumberList;
    }

    private Integer getSerialNumberById(Id acctPeriodId) {
        return allSerialNumbersByAcctPeriodId.get(acctPeriodId);
    }

    //If there is no next/previous/matching by given offset Accounting Period in Data Base
    //we will provide fake Accounting Period with Name set with assumption that Accounting Period spans one calendar month
    //This will help us to avoid NULL reference in Report Generation business logic
    @TestVisible
    private Accounting_Period__c getFakePeriodFromOffset(Id currentAcctPeriodId, Integer periodOffset) {
        Accounting_Period__c result;
        Accounting_Period__c currentAccountingPeriod;
        for (Accounting_Period__c eachAcctPeriod : allAcctPeriodsByName.values()) {
            if (eachAcctPeriod.Id == currentAcctPeriodId) {
                currentAccountingPeriod = eachAcctPeriod;
                break;
            }
        }
        Integer year = Integer.valueOf(currentAccountingPeriod.Name.substring(0, 4));
        Integer period = Integer.valueOf(currentAccountingPeriod.Name.substring(5));
        Date newDate = Date.newInstance(year, period, 1);
        newDate = newDate.addMonths(periodOffset);
        String fakeAcctPeriodName =
            String.valueOf(newDate.year()) +
                '-' +
                (newDate.month() < 10 ? '0' + String.valueOf(newDate.month()) : String.valueOf(newDate.month()));

        result = new Accounting_Period__c(
            Name = fakeAcctPeriodName,
            Start_Date__c = newDate,
            End_Date__c = newDate.addMonths(1).addDays(-1)
        );
        return result;
    }


    public static Boolean areAccPeriodsExisting(Date startDate,
                                                Date endDate,
                                                List<Accounting_Period__c> openOrderedAccgPeriods) {

        if (openOrderedAccgPeriods.isEmpty()
                || startDate < openOrderedAccgPeriods[0].Start_Date__c
                || endDate > openOrderedAccgPeriods[openOrderedAccgPeriods.size()-1].End_Date__c) {

            return false;
        }

        Date expectedStartOfNextPeriod = openOrderedAccgPeriods[0].Start_Date__c;

        for (Integer i = 0; i < openOrderedAccgPeriods.size(); i++) {
            if (expectedStartOfNextPeriod != openOrderedAccgPeriods[i].Start_Date__c ) { //valid case if dates equals
                return false;
            }
            expectedStartOfNextPeriod = openOrderedAccgPeriods[i].End_Date__c.addDays(1);
        }

        return true;
    }

    public Accounting_Period__c getFinancialReportStartPeriod(Id endPeriod, Integer periodRangeLimit) {
        Accounting_Period__c startPeriod;
        if (endPeriod != NULL && periodRangeLimit != NULL) {
            for (Integer offset = (periodRangeLimit - 1); offset >= 0; offset--) {
                Accounting_Period__c tempStartPeriod = getAccountingPeriodByOffset(endPeriod, offset * -1);
                if (tempStartPeriod?.Id != NULL) {
                    startPeriod = tempStartPeriod;
                    break;
                }
            }
        }
        return startPeriod;
    }

    public Accounting_Period__c getFinancialReportEndPeriod() {
        return getAccountingPeriodByDate(Date.today());
    }

    public Accounting_Period__c getFirstOpenedPeriod(sObjectType sobjType) {

        Accounting_Period__c firstOpenedPeriod;
        List<Accounting_Period__c> allClosedPeriodsWithDescSort = getAllAccountingPeriods(
            new Set<String>{AccountingPeriodActions.CLOSED_STATUS, AccountingPeriodActions.ARCHIVED_STATUS},
            SOQLBuilder.SortOrder.DESCENDING, sobjType
        );

        if (!allClosedPeriodsWithDescSort.isEmpty()) {
            firstOpenedPeriod = getNextAccountingPeriod(allClosedPeriodsWithDescSort[0]);
        }
        else {
            firstOpenedPeriod = getAllAccountingPeriods().get(0);
        }
        return firstOpenedPeriod;
    }

    public Accounting_Period__c getFirstOpenedPeriod() {
        return getFirstOpenedPeriod(null);
    }

    public Accounting_Period__c getFirstPeriodWithStatusOpen() {
        Accounting_Period__c firstOpenedPeriod;
        List<Accounting_Period__c> allOpenPeriodsWithASCSort = getAllAccountingPeriods(
            new Set<String>{AccountingPeriodActions.OPEN_STATUS},
            SOQLBuilder.SortOrder.ASCENDING
        );

        if (!allOpenPeriodsWithASCSort.isEmpty()) {
            firstOpenedPeriod = allOpenPeriodsWithASCSort[0];
        }
        else {
            firstOpenedPeriod = getAllAccountingPeriods().get(0);
        }

        return firstOpenedPeriod;
    }

    public Boolean isDateWithinTheAccountingPeriod(Date aDate, Id aPeriod) {
        Boolean result = false;
        if (aDate != NULL && aPeriod != NULL) {
            result = aPeriod == getAccountingPeriodByDate(aDate)?.Id;
        }
        return result;
    }

    public Integer getNumberOfPrecededOpenPeriods(Id periodId) {
        //==============================================================================================
        // Query must be executed in the System Context to count the number of open accounting periods
        // regardless of current user permissions. This is used to implement application business rule.
        //==============================================================================================
        List<Accounting_Period__c> previousOpenAccountingPeriods =
            getPreviousAccountingPeriods(
                periodId, new Set<String>{
                    AccountingPeriodActions.OPEN_STATUS,
                    AccountingPeriodActions.CLOSE_INTERIM_STATUS
                }
            );

        return previousOpenAccountingPeriods.size();
    }

}