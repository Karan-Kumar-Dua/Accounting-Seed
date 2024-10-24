public with sharing class TimeCardControllerExt {

    public static final String LAST_MODIFIED_ERROR = Label.ERR_LAST_MODIFIED;
    
    private List<Time_Card_Line__c> removedRowsList;
    private DateTime lastModifiedDate;
    private ApexPages.StandardController controller;
    private Integer rowCount;

    public Integer selectedRow {get; set;} // This is the selected row for the wrapper list row
    public Map<Integer, TimeCardHelper.TimeCardLineWrapper> wrapperMap {get; set;}
    public Time_Card__c timeCard {get; set;}
    public TimeCardHelper.TimeCardUIConfiguration uiConfig {get; private set;}
    public Boolean isError {get; private set;}

    //constructor
    public TimeCardControllerExt(ApexPages.StandardController controller) {
        
        try {
            timeCard = TimeCardHelper.queryTimeCard(controller.getId());

            lastModifiedDate = timeCard.LastModifiedDate;
            this.controller = controller;
            timeCard.Ledger__c = timeCard.Ledger__c == NULL ? LedgerHandler.getLegacyDefaultLedgerId() : timeCard.Ledger__c;
            removedRowsList = new List<Time_Card_Line__c>();
            wrapperMap = TimeCardHelper.wrapTimeCardLines(timeCard, true);
            rowCount = TimeCardHelper.lastRowIndex;
            uiConfig = TimeCardHelper.getTimeCardUIConfiguration(false);
            isError = false;
        } 
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            isError = true;
        }

    }

    public List<String> getDayHeaders() {
        return TimeCardHelper.getTimePeriodDayHeaders(this.timeCard);
    }
    
    public Double getTimeCardTotal() {
        Double total = 0;
        if (wrapperMap.values() != NULL) {
            for (TimeCardHelper.TimeCardLineWrapper tcw : wrapperMap.values()) {
                total += tcw.getLineTotal();
            }  
        }
        return total;
    } 
    
    //Add new Time line item to list
    public void addTimeCardLineItem() {
        rowCount++;
        wrapperMap.put(
            rowCount,
            new TimeCardHelper.TimeCardLineWrapper(
                timeCard,
                new Time_Card_Line__c(),
                rowCount,
                NULL,
                new List<SelectOption>{new SelectOption('', Label.SELECT_OPTION_NONE)}
            )
        );
    }
    
    //Remove Time line item from list
    public PageReference deleteTimeCardLineItem() {
        TimeCardHelper.TimeCardLineWrapper det = wrapperMap.remove(selectedRow);
        if (det.timeCardLine.Id != NULL) {
            removedRowsList.add(det.timeCardLine);
        }
        return NULL;
    }
    
    public List<TimeCardHelper.TimeCardLineWrapper> getWrapperList() {
        return wrapperMap.values();
    }     
    
    //Add comments to time line. Saves the EXPDET__c record and redirects to the EXPDET__C edit page.
    public PageReference showComments() {
         if (extSave() == NULL) {
            return NULL;
         }
         else {
            return new PageReference('/apex/TimeCardLineEdit?id=' + wrapperMap.get(selectedRow).timeCardLine.Id);
         }
    }
     
    //Refresh page for calculations
    public PageReference recalcPage(){
        if (extSave() == NULL) {
            return NULL;
        }
        return controller.edit();
    }
    
    //Upsert header and detail records
    public PageReference extSave() {
        SavePoint sp = Database.setSavepoint();
        List<Time_Card_Line__c> rollBackTimeCardLineList = new List<Time_Card_Line__c>();

        Set<Time_Card_Day__c> updateList = new Set<Time_Card_Day__c>();
        List<Time_Card_Day__c> insertList = new List<Time_Card_Day__c>();
        List<Time_Card_Day__c> deleteList = new List<Time_Card_Day__c>();
        try {
            Boolean isError = false;

            // Accessible and FLS checks performed in class constructor. Redundant to perform same checks here.
            DateTime checkLastModifiedDate =
                DomainUtils.getTimeCardsByIdForUpdate(new Set<Id>{timeCard.Id})[0].LastModifiedDate;

            // Has the time card been modified by another process?
            if (checkLastModifiedDate != lastModifiedDate) {
                ApexPages.addMessage(new ApexPages.MESSAGE(ApexPages.SEVERITY.ERROR, LAST_MODIFIED_ERROR));
                return NULL;
            }
    
            List<Time_Card_Line__c> timeCardLineList = new List<Time_Card_Line__c>();
            for (TimeCardHelper.TimeCardLineWrapper wr : wrapperMap.values()) {
                
                if (wr.timeCardLine.Project_Task__c == NULL) {
                    wr.isProjectTaskError = true;
                    isError = true;
                }
                else {
                    wr.isProjectTaskError = false;
                }
                
                if (wr.timeCardLine.Project__c == NULL) {
                    wr.isProjectError = true;
                    isError = true;
                }
                else {
                    wr.isProjectError = false;
                }
                
                if (wr.timeCardLine.Time_Card__c == NULL) {
                    wr.timeCardLine.Time_Card__c = timeCard.Id;
                }
                timeCardLineList.add(wr.timeCardLine);

                if (wr.timeCardLine.Id == NULL) {
                    rollBackTimeCardLineList.add(wr.timeCardLine);
                }
            }
            
            if (!isError) {
                SFDCSecurityUtils.updateCheckCRUDAndFLS(controller.getRecord(), new List<String>{'Status__c'});

                SFDCSecurityUtils.upsertCheckCRUDAndFLS(timeCardLineList, new List<String>{
                    'Project__c',
                    'Project_Task__c'
                });

                for (TimeCardHelper.TimeCardLineWrapper wr : wrapperMap.values()) {
                    for (Time_Card_Day__c day : wr.days) {
                        if (day.Time_Card_Line__c == NULL) {
                            day.Time_Card_Line__c = wr.timeCardLine.Id;
                        }

                        if (day.Id != NULL) {
                            if (day.Hours__c != NULL) {
                                updateList.add(day);
                            } else if (day.Hours__c == NULL) {
                                deleteList.add(day);
                            }
                        }
                        else if (day.Hours__c != NULL && day.Id == NULL) {
                            insertList.add(day);
                        }
                    }
                }

                SFDCSecurityUtils.updateCheckCRUDAndFLS( new List<Time_Card_Day__c>(updateList), new List<String>{'Hours__c'});
                SFDCSecurityUtils.insertCheckCRUDAndFLS(insertList, new List<String>());
                SFDCSecurityUtils.deleteCheckCRUDAndFLS(deleteList);
                SFDCSecurityUtils.deleteCheckCRUDAndFLS(removedRowsList);

                removedRowsList.clear();
                deleteList.clear();

                // Accessible and FLS checks performed in class constructor. Redundant to perform same checks here.
                lastModifiedDate = DomainUtils.getTimeCardsById(new Set<Id>{timeCard.Id})[0].LastModifiedDate;
                return controller.view();
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            for (Time_Card_Day__c tcd : insertList) {
                tcd.Id = NULL;
            }
            for (Time_Card_Line__c tcl : rollBackTimeCardLineList) {
                tcl.Id = NULL;
            }
            for (TimeCardHelper.TimeCardLineWrapper wr : wrapperMap.values()) {
                for (Time_Card_Day__c day : wr.days) {
                    if (day.Id == NULL) {
                        day.Time_Card_Line__c = NULL;
                    }
                }
            }

            ApexPages.addMessages(ex);
        }
        return NULL;
    }

}