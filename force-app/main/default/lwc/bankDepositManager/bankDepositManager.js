import { LightningElement, api, wire,track } from 'lwc';
import FieldsSelectionModal from 'c/fieldsSelectionModal';
import CURRENCY from '@salesforce/i18n/currency';
import { LabelService, NotificationService}  from "c/utils";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";
import { bankDepositManagerLabels } from './bankDepositManagerLabels';
import BANK_DEPOSIT_DATE from "@salesforce/schema/Bank_Deposit__c.Deposit_Date__c";
import BANK_DEPOSIT_AMOUNT from '@salesforce/schema/Bank_Deposit__c.Amount__c'
import getDatatableColumns from '@salesforce/apex/BankDepositManagerLWC.getDatatableColumns';
import saveColumnDetails from '@salesforce/apex/BankDepositManagerLWC.saveColumnDetails';
import getCashReceiptNdJEL from '@salesforce/apex/BankDepositManagerLWC.getCashReceiptNdJEL';
import updateCashReceiptNdJEL from '@salesforce/apex/BankDepositManagerLWC.updateCashReceiptNdJEL';
import queryBankDepositRecord from '@salesforce/apex/BankDepositManagerLWC.queryBankDepositRecord';
import getTotalCRRecords from '@salesforce/apex/BankDepositManagerLWC.getTotalCRRecords';
import getTotalJELRecords from '@salesforce/apex/BankDepositManagerLWC.getTotalJELRecords'

export default class BankDepositManager extends LightningElement {
    labels = {...LabelService, ...bankDepositManagerLabels()}
    @api recordId;
    currentActiveTab;
    previousActiveTab;
    objectTypeVal = 'All'
    fieldsToAdd;
    isLoading;
    labelNdObjNameWithFldName = {};
    @track columns ;
    @track clonedColumns;
    @track clonedRecordData;
    @track associatedRecords
    @track unassociatedRecords
    @track selectedRows;
    @track selectedAssociateRowIds;
    @track selectedUnassociateRowIds;
    bankDeposit;
    currencyIsoCode

    totalRecordsCount = 0;
    totalCRrecords = 0;
    totalJELrecords = 0;
    initialquerylimit = 4;
    queryLimitForJEL = this.initialquerylimit;
    queryLimitForCR = this.initialquerylimit;
    lastFetchedRecordId = '';
    recordsfetchedIteration = 0;
    isPageChanged = false;

    @wire(getRecord,{ recordId: "$recordId", fields: [BANK_DEPOSIT_DATE,BANK_DEPOSIT_AMOUNT]})
    fetchBankDeposit(result){
        this.bankDeposit = result;
        let {data,error} = result;
        if(data){ 
            this.setDefaultDate(getFieldValue(data, BANK_DEPOSIT_DATE)); 
            this.fetchCurrencyIsoCode();
        }else if(error){
            this.showErrorNotification(JSON.stringify(error), this.labels.ERR_FETCHING_BANKDEPOSIT_RECORD);
        }
    }

    async connectedCallback(){
        this.isLoading = true
        this.fieldsToAdd = []
        this.selectedRows = []
        this.associatedRecords = []
        this.unassociatedRecords = []
        this.selectedAssociateRowIds = []
        this.selectedUnassociateRowIds = []
        this.currentActiveTab = this.labels.COMMON_ASSOCIATE;
        this.previousActiveTab = this.currentActiveTab;
        await this.prepareColumns();
        await this.getCashReceiptAndJEL()
        // this.fetchCashReceiptNdJEL();    
    }
   
    get objectTypeOptions(){
        return [
            { label: this.labels.COMMON_ALL_LABEL, value: this.labels.COMMON_ALL_LABEL },
            { label: this.labels.COMMON_CASH_RECEIPT, value: this.labels.COMMON_CASH_RECEIPT },
            { label: this.labels.JOURNAL_ENTRY_LINE_TYPE_LABEL, value: this.labels.JOURNAL_ENTRY_LINE_TYPE_LABEL }
        ];
    }

    get bankDepositAmount(){
      return getFieldValue(this.bankDeposit.data, BANK_DEPOSIT_AMOUNT)
    }

    get getErrorMsg(){
        let recordData = this.isActiveTabAssociate() ? this.associatedRecords : this.unassociatedRecords;
        if(!recordData || recordData.length == 0){
            return this.labels.NO_RECORDS_FOUND_LABEL_FOR_BANKDIS_MANAGER + ' ' + this.labels.INFO_NO_RECORD_MSG;
        }
        return ''
    }

    fetchCurrencyIsoCode(){
	    queryBankDepositRecord({recordId : this.recordId}).then(record=>{
            if(record.hasOwnProperty('CurrencyIsoCode')){
                this.currencyIsoCode = record.CurrencyIsoCode
            }else{
                this.currencyISOCode = CURRENCY
            }
        })
    }


    async getCashReceiptAndJEL(){
       await this.getTotalRecordCount(this.buildFiltersObj())
       this.recordsfetchedIteration = 1;
       this.fetchCashReceiptNdJEL()
    }

    async getTotalRecordCount(filterObj) {
        try {
            
            this.totalCRrecords = await this.fetchTotalRecordsCount(getTotalCRRecords, filterObj);
            this.totalJELrecords = await this.fetchTotalRecordsCount(getTotalJELRecords, filterObj);
            this.totalRecordsCount = this.totalCRrecords + this.totalJELrecords;
        } catch (error) {
            this.showErrorNotification(error?.body?.message, this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
        }
    }

    get hasMoreRecordsToLoad() {
        if(this.isActiveTabAssociate()){
            return !this.associatedRecords || this.associatedRecords.length < this.totalRecordsCount;
        } else {
            return !this.unassociatedRecords || this.unassociatedRecords.length < this.totalRecordsCount;
        }
    }

    handleLoadMoreRecords(evt){
        this.recordsfetchedIteration = 2;
        this.loadMore(evt.detail.offset);
    }

    async loadMore(offset) {
        this.isLoading = true;
        try {
            this.calculateQueryLimitForObjects();
            const filtersObj = this.buildFiltersObj();
            filtersObj['lastFetchedRecordId'] = this.lastFetchedRecordId;
            filtersObj['cashReceipt'] = this.labelNdObjNameWithFldName['Cash_Receipt__c'] != undefined ? (this.labelNdObjNameWithFldName['Cash_Receipt__c'] + ',Name') : 'Name';
            filtersObj['journalEntryLine'] = this.labelNdObjNameWithFldName['Journal_Entry_Line__c'] != undefined ? (this.labelNdObjNameWithFldName['Journal_Entry_Line__c'] + ',Name' ) : 'Name'; 

            if (this.validateFields()) {
                this.recordsfetchedIteration += 1;
                const result = await getCashReceiptNdJEL({bankDepositId : this.recordId, filtersObj : JSON.stringify(filtersObj), currentTab : this.currentActiveTab})
                if(result && result.length > 0){        
                    this.processCashReceiptNdJELRecords(result);
                    let data = []
                    if(this.isActiveTabAssociate()){
                        this.associatedRecords = this.filterRecords(this.associatedRecords)
                        data = this.associatedRecords;
                        this.lastFetchedRecordId =  this.associatedRecords[this.associatedRecords.length -1].Id;
                        
                    } else if(this.isActiveTabUnassociate()){
                        this.unassociatedRecords =  this.filterRecords(this.unassociatedRecords)
                        this.lastFetchedRecordId = this.unassociatedRecords[this.unassociatedRecords.length - 1].Id;
                        data = this.unassociatedRecords;                  
                    }

                    if (data.length < this.totalRecordsCount) {
                        await this.loadMore(offset);
                    } else if (offset >= 0) {
                        this.moveToPageNumber(offset);
                    }
                    this.clonedRecordData = data;
                }
            }
        } catch (error) {
            this.showErrorNotification(JSON.stringify(error?.body?.message), this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
        } finally {
            this.isLoading = false;
        }
    }

    filterRecords(recordData){
        const uniqueNames = new Set();
        return recordData.filter(item => {
            if (!uniqueNames.has(item.Name)) {
                uniqueNames.add(item.Name);
                return true; 
            }
            return false; 
        });
    
    }

    
    async moveToPageNumber(offset) {
        let dataTable = this.template.querySelector('c-bank-deposit-manager-result-data-table');
        if (dataTable) {
            this.isPageChanged = true;
            await Promise.resolve();
            if (offset >= 0) {
                dataTable.moveToPage(offset);
            } else {
                dataTable.moveToPage(1);
            }
        }
    }


    async calculateQueryLimitForObjects() {   
        this.queryLimitForCR = this.initialquerylimit;
        this.queryLimitForJEL = this.initialquerylimit;
       
        const totalCRrecords = parseInt(this.totalCRrecords, 10) || 0;
        const totalJELrecords = parseInt(this.totalJELrecords, 10) || 0;
        const recordsfetchedIteration = parseInt(this.recordsfetchedIteration, 10) || 0;
        const initialQueryLimit = parseInt(this.initialquerylimit, 10) || 0;
        let remainingCRrecs = (totalCRrecords > ((recordsfetchedIteration - 1) * initialQueryLimit)) 
            ? totalCRrecords - ((recordsfetchedIteration - 1) * initialQueryLimit) 
            : 0;

        let remainingJELrecs = (totalJELrecords > ((recordsfetchedIteration - 1) * initialQueryLimit)) 
            ? totalJELrecords - ((recordsfetchedIteration - 1) * initialQueryLimit) 
            : 0;

        
        if((remainingCRrecs > this.initialquerylimit || remainingJELrecs > this.initialquerylimit) && 
            (remainingCRrecs + remainingJELrecs > 2* this.initialquerylimit)){
                if(remainingCRrecs > this.initialquerylimit){
                    this.queryLimitForCR = this.initialquerylimit;
                }else{
                    this.queryLimitForCR = remainingCRrecs;
                }
                if(remainingJELrecs > this.initialquerylimit){
                    this.queryLimitForJEL = this.initialquerylimit;
                }else{
                    this.queryLimitForJEL = remainingJELrecs;
                }
        }else{
            this.queryLimitForCR = remainingCRrecs;
            this.queryLimitForJEL = remainingJELrecs;
        }  
    }

    async fetchTotalRecordsCount(apexMethod, filterObj) {
        return apexMethod({ bankDepositId: this.recordId, filtersJSON: JSON.stringify(filterObj), currentTabVal : this.currentActiveTab })
            .then(result => parseInt(result, 10))
            .catch(error => {
                this.showErrorNotification(error, this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
                return 0;
            });
    }
  
    fetchCashReceiptNdJEL(){
        let filtersObj = this.buildFiltersObj();

        filtersObj['cashReceipt'] = this.labelNdObjNameWithFldName['Cash_Receipt__c'] != undefined ? 
                                            (this.labelNdObjNameWithFldName['Cash_Receipt__c'] + ',Name') : 'Name';
        filtersObj['journalEntryLine'] = this.labelNdObjNameWithFldName['Journal_Entry_Line__c'] != undefined ? 
                                            (this.labelNdObjNameWithFldName['Journal_Entry_Line__c'] + ',Name' ) : 'Name'; 
       
        
        if(filtersObj != undefined &&  filtersObj != null){
            getCashReceiptNdJEL({bankDepositId : this.recordId, filtersObj : JSON.stringify(filtersObj), currentTab : this.currentActiveTab})
            .then(result=>{
               if(result != undefined || result != null){
                   this.processCashReceiptNdJELRecords(result);
               } 
            })
            .catch(error=>{
               this.isLoading = false;
               this.showErrorNotification(JSON.stringify(error?.body?.message), this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
            })    
        }  
    }

    processCashReceiptNdJELRecords(result){
        try{
            let updatedColumns = []
           
            const formatCurrency = (amount,currency,record) => { 
                let symbol = record?.sourceObj?.sourceType == 'Debit Journal' ? '-' : ' ';
                return `${currency} ${symbol}${amount.toFixed(2)}`;
            }
    
            const getFieldData = (record ,colItem) => {
                return record.obj[colItem.fieldName] || record.obj[this.labelNdObjNameWithFldName[colItem.label][1]] || null
       
            }
    
            const formatDate = (recordDate) =>{
              
                if(recordDate != null){
                    const dateObj = new Date(recordDate);
                    const day = String(dateObj.getDate())
                    const month = String(dateObj.getMonth() + 1).padStart(2, '0'); // Months are zero-indexed
                    const year = dateObj.getFullYear();
                    return `${month}/${day}/${year}`;
                }
                return '';
            }
           
            result.forEach(record=>{
                let data = {};
              
                updatedColumns = this.clonedColumns.map(colItem=>{
                    if(colItem.type == 'url'){
                        if(colItem.fieldName == 'recordUrl'){
                            data[colItem.fieldName] = `${record.sourceObj.baseURL}/${record.sourceObj.sourceId}`;
                            data[colItem.typeAttributes.label.fieldName] = record.obj[colItem.typeAttributes.label.fieldName]
                        }
                    } else if(colItem.type == 'currency'){    
                        data[colItem.fieldName] = formatCurrency(getFieldData(record,colItem),record.obj.CurrencyIsoCode,record)
                        return {...colItem,type:'text'}
                    } else if(colItem.type == 'Date'){
                        data[colItem.fieldName] = formatDate(getFieldData(record,colItem))
                    } else if(colItem.fieldName.includes('__r')){
                        data[colItem.fieldName] = record.obj?.[colItem.fieldName.split('.')[0]]?.[colItem.fieldName.split('.')[1]];
                        data[colItem.fieldName] = data[colItem.fieldName] != undefined ? data[colItem.fieldName] : '';
                    } else{
                        data[colItem.fieldName] = getFieldData(record,colItem)
                    }
                    return {...colItem}
                    })
                
                data['Id'] = record.obj.Id;
                
                if(this.isActiveTabAssociate()){
                    this.associatedRecords.push(data)
                } else if(this.isActiveTabUnassociate()){
                    this.unassociatedRecords.push(data)
                }
               
            }) 
            this.columns = updatedColumns.length != 0 ? updatedColumns : this.columns; 
            if(this.isActiveTabAssociate()){
                this.clonedRecordData = this.associatedRecords
            } else if(this.isActiveTabUnassociate()){
                this.clonedRecordData = this.unassociatedRecords
            }
            this.lastFetchedRecordId = (this.clonedRecordData && this.clonedRecordData.length > 0) ?  this.clonedRecordData[this.clonedRecordData.length - 1].Id : '';
            this.isLoading = false;
        }catch(error){
            this.showErrorNotification(JSON.stringify(error?.message), this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
        }
    }

    isActiveTabAssociate(){
        return this.currentActiveTab == this.labels.COMMON_ASSOCIATE;
    }

    isActiveTabUnassociate(){
        return this.currentActiveTab == this.labels.COMMON_UNASSOCIATE;
    }
 
    async handleTabChange(event){
        try{
            this.isLoading = true;
            let selectAssociateButton = this.getAssociateBtnElement();
            let selectUnAssociateButton = this.getUnassociateBtnElement();
            selectAssociateButton.disabled = true;
            selectUnAssociateButton.disabled = true;

            let previousActiveTab = this.currentActiveTab;
            this.currentActiveTab = event.target.dataset.id
        
            if(previousActiveTab != this.currentActiveTab){
                if((this.isActiveTabAssociate() && this.associatedRecords.length == 0) 
                    || this.isActiveTabUnassociate() && this.unassociatedRecords.length == 0){
                        
                        this.queryLimitForCR = this.initialquerylimit
                        this.queryLimitForJEL = this.initialquerylimit
                       await this.getCashReceiptAndJEL()

                } else {
                  
                    selectUnAssociateButton.disabled = !(this.isActiveTabAssociate() && this.selectedAssociateRowIds.length != 0) 
                    selectAssociateButton.disabled  =  !(this.isActiveTabUnassociate() && this.selectedUnassociateRowIds.length != 0)
                    this.isLoading = false
                }
            }      
        }catch(error){
            this.showErrorNotification(JSON.stringify(error?.body?.message), this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
        }
    }

    getAssociateBtnElement(){
        return  this.template.querySelector('[data-id="associateSelectedBtn"]')
    }
    
    getUnassociateBtnElement(){
        return this.template.querySelector('[data-id="unassociateSelectedBtn"]')
    }

    buildFiltersObj() {
        const filtersObj = {};
        try{
            this.template.querySelectorAll('.inputFields').forEach(item => {
                filtersObj[item.dataset.id] = item.value;
            });  

            filtersObj['queryLimitForCR'] = this.queryLimitForCR;
            filtersObj['queryLimitForJEL'] = this.queryLimitForJEL;
            
        }catch(error){
            this.showErrorNotification(JSON.stringify(error?.body?.message), this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
        }
        return filtersObj;   
    }

    async fetchDatatableColumns(){
        try{
            this.fieldsToAdd = await getDatatableColumns();
        }catch(error){
            this.showErrorNotification(JSON.stringify(error), this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
            
        }
    }

    async openFieldsSelectionModal(){
        try{

            let result =  await FieldsSelectionModal.open({
                allFields: this.fieldsToAdd,
                size: 'small'
            })
            this.isLoading = true;
            this.populateRecords([],[])
            await this.saveColumnData(result)
            await this.prepareColumns();
            this.fetchCashReceiptNdJEL()
        }catch(error){
            this.showErrorNotification(JSON.stringify(error?.body?.message), this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
        }
    }

    async prepareColumns(){
        try{
            await this.fetchDatatableColumns(); 
            this.columns = [{label: this.labels.COMMON_NAME, fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }}]  
            this.labelNdObjNameWithFldName = {}
            
            this.fieldsToAdd.forEach(item=>{
                if('AcctSeed__Add_Field__c' in item && item.AcctSeed__Add_Field__c){
                    let obj = {
                        label: item.AcctSeed__label__c,
                        fieldName: item.AcctSeed__Cash_Receipt_Field__c,
                        type: item.AcctSeed__Type__c
                    } 
                    this.columns.push(obj);
                    this.prepareQueryFieldMappings(item);    
                }
            })

            this.clonedColumns = this.columns;
            if(!this.labelNdObjNameWithFldName['Cash_Receipt__c']){
                this.labelNdObjNameWithFldName['Cash_Receipt__c']  = this.labelNdObjNameWithFldName['Cash_Receipt__c'].replace(/,$/, '')
            }
            if(!this.labelNdObjNameWithFldName['Journal_Entry_Line__c']){
                this.labelNdObjNameWithFldName['Journal_Entry_Line__c'] = this.labelNdObjNameWithFldName['Journal_Entry_Line__c'].replace(/,$/, '');
            }
        }catch(error){
            this.showErrorNotification(JSON.stringify(error?.body?.message), this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
        }
       
    }

    prepareQueryFieldMappings(item){
        this.labelNdObjNameWithFldName[item.AcctSeed__label__c]  = [item.AcctSeed__Cash_Receipt_Field__c , item.AcctSeed__Journal_Entry_Line_Field__c];
        this.labelNdObjNameWithFldName['Cash_Receipt__c'] =     this.labelNdObjNameWithFldName['Cash_Receipt__c'] ? 
                                                                    this.labelNdObjNameWithFldName['Cash_Receipt__c'] + item.AcctSeed__Cash_Receipt_Field__c + ',' 
                                                                                : item.AcctSeed__Cash_Receipt_Field__c + ',';
                    
        this.labelNdObjNameWithFldName['Journal_Entry_Line__c'] = this.labelNdObjNameWithFldName['Journal_Entry_Line__c'] ?
                                                                    this.labelNdObjNameWithFldName['Journal_Entry_Line__c'] + item.AcctSeed__Journal_Entry_Line_Field__c +','
                                                                                : item.AcctSeed__Journal_Entry_Line_Field__c + ',';    
    }



    async saveColumnData(result) {
        try{
            if (result != undefined) {
                let columnObj = {};
            
                result.fieldsToAdd.forEach(Id=>{
                    columnObj[Id] = true;
                })
                result.fieldsToRemove.forEach(Id=>{
                    columnObj[Id] = false;
                })
                await saveColumnDetails({columnData : JSON.stringify(columnObj)})   
            }
        }catch(error){
            this.showErrorNotification(JSON.stringify(error?.body?.message), this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
        }	
    }

    setDefaultDate(bankDepositDate){
        const bankDepositDateObj = new Date(bankDepositDate);
        const startDateObj = new Date(bankDepositDateObj);
        startDateObj.setDate(bankDepositDateObj.getDate() - 30);
        const formatDate = date => date.toISOString().split('T')[0];
        
        this.template.querySelector('lightning-input[data-id="startDate"]').value = formatDate(startDateObj);
        this.template.querySelector('lightning-input[data-id="endDate"]').value = formatDate(bankDepositDateObj);
    }

    handleObjectTypeSelection(event){
        this.objectTypeVal = event.target.value;
    }

    handleSearchInput(event){
        this.isLoading = true;
        const searchKey = event.target.value.toLowerCase();
        clearTimeout(this.typingTimeout);
        this.typingTimeout = setTimeout(() => {
            if(searchKey){
                this.lastFetchedRecordId = ''
                this.handleKeyChangeHelper(searchKey);     
            }else{
                this.populateRecords(this.clonedRecordData,this.clonedRecordData)
            }
            this.isLoading  = false
        },400)
    }

    async handleKeyChangeHelper(searchKey){
        await this.loadMore(-1)
        let recordData = this.isActiveTabAssociate() ?  this.associatedRecords : this.unassociatedRecords
        this.clonedRecordData = recordData;
        this.filterData(searchKey,recordData) 
    }

    filterData(searchKey,recordData){
        recordData = recordData.filter(record => {
            return Object.entries(record).some(([field,value]) => {
                if(value){
                    if(field.toLowerCase().includes('amount')){
                        return value.replace(/^[A-Za-z]{3}\s/, "").trim().startsWith(searchKey)
                    }
                    if (field != 'recordUrl' && field != 'Id') {
                        return value.toString().toLowerCase().startsWith(searchKey)
                    }
                }
                return false;
            });
        });
        this.populateRecords(recordData,recordData)
        this.moveToPageNumber(0)
       
    }

    handleRecordSearch(event) {
        if(this.validateFields()){
            this.populateRecords([],[])
            this.isLoading = true;

            this.fetchCashReceiptNdJEL();
        } else{
            this.populateRecords(this.associatedRecords,this.unassociatedRecords)
        }
    }

    populateRecords(associatedRecords,unassociatedRecords){
        if(this.isActiveTabAssociate()){
            this.associatedRecords = associatedRecords
        } else if(this.isActiveTabUnassociate()) {
            this.unassociatedRecords = unassociatedRecords
        }
    }

    
    handleRowSelection(event) {
        let selectedRowIds = []
        if(this.isActiveTabAssociate()){
            selectedRowIds = this.selectedAssociateRowIds
        } else if(this.isActiveTabUnassociate()){
            selectedRowIds = this.selectedUnassociateRowIds
        }
        switch(event?.detail?.config?.action){
            case 'selectAllRows':
                for (let i = 0; i < event.detail.selectedRows.length; i++) {
                    selectedRowIds.push(event.detail.selectedRows[i].Id);
                }
                break;
            case 'deselectAllRows':
                selectedRowIds = selectedRowIds.filter(Id => !event.detail.delectedRows.includes(Id))
                break;
            case 'rowSelect':
                selectedRowIds.push(event.detail.config.value);
                break;
            case 'rowDeselect':
                let index = selectedRowIds.indexOf(event.detail.config.value);
                if (index != -1) {
                    selectedRowIds.splice(index, 1);
                }
                break;
            default:
                break;
        }

        let selectAssociateButton = this.getAssociateBtnElement();
        let selectUnAssociateButton = this.getUnassociateBtnElement();

        if(this.isActiveTabUnassociate()){
            selectAssociateButton.disabled = (selectedRowIds.length <= 0);
            this.selectedUnassociateRowIds = selectedRowIds
        }else if(this.isActiveTabAssociate()){
            selectUnAssociateButton.disabled = (selectedRowIds.length <= 0);
            this.selectedAssociateRowIds = selectedRowIds
        } 
    }   
        
    async handleButtonClick(event){ 
        this.isLoading = true
        let recordIds = []
        let isAssociation =  false;
        if(this.isActiveTabAssociate()){
            recordIds = this.selectedAssociateRowIds
        } else if(this.isActiveTabUnassociate()){
            recordIds = this.selectedUnassociateRowIds;
            isAssociation = true
        }

        updateCashReceiptNdJEL({recordsIdsToUpdate : JSON.stringify(recordIds),bankDepositId: this.recordId,isAssociation : isAssociation})
        .then(result =>{
            if(this.isActiveTabAssociate()){
                this.unassociatedRecords = []
            } else {
                this.associatedRecords = []
            }
            refreshApex(this.bankDeposit)
           
            let message = this.isActiveTabAssociate() ? this.labels.SUCCESS_MSG_AFTER_UNASSOCIATED_RECS_ON_BANKDISB_LWC : this.labels.SUCCESS_MSG_AFTER_ASSOCIATED_RECS_ON_BANKDISB_LWC
           
            this.getTotalRecordCount(this.buildFiltersObj()).then(result=>{
                
                this.updateResultData();
                if(this.totalRecordsCount > 0){
                    this.moveToPageNumber(0);
                }
                this.showSuccessNotification(message)
            })
            .catch(error=>{
                this.showErrorNotification(JSON.stringify(error?.body?.message), this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
            })  
            this.isLoading = false;        
        }).catch(error => {
            this.isLoading = false;
            this.showErrorNotification(JSON.stringify(error?.body?.message), this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
        })
    }

    updateResultData(){
        let data = []
        let selectedRowIds; 
        if(this.isActiveTabAssociate()){
            data = this.associatedRecords;
            selectedRowIds = this.selectedAssociateRowIds;
            this.selectedAssociateRowIds = []
        } else if(this.isActiveTabUnassociate()){
            data = this.unassociatedRecords;
            selectedRowIds = this.selectedUnassociateRowIds
            this.selectedUnassociateRowIds = []
        }

        let filteredData = []
        filteredData =  data.filter(row => !selectedRowIds.includes(row.Id))
        this.populateRecords(filteredData,filteredData)   
    }

    handleBlur(event){
        this.validateFields();     
    }

    validateFields(){
        try{
            const allValid = [
                ...this.template.querySelectorAll('.inputFields'),
            ].reduce((validSoFar, inputCmp) => {
                
                if(!inputCmp.checkValidity()){
                    let message = inputCmp.dataset.id == 'startDate' ? 'Start Date' :  ((inputCmp.dataset.id == 'endDate') ? ' End Date' : '')   
                    inputCmp.setCustomValidity(`Enter valid ${message}`)
                    inputCmp.reportValidity()
                }
                
                return validSoFar && inputCmp.checkValidity();
            }, true);
            return allValid;
        }catch(error){
            this.showErrorNotification(JSON.stringify(error?.body?.message), this.labels.ERR_IN_BANK_DEPOSIT_MANAGER_COMPONENT);
        }
        
    }

    showErrorNotification(message, title) {
        NotificationService.displayToastMessage(this, message, title, this.labels.commonErrorText);
    }

    showSuccessNotification(message) {
        NotificationService.displayToastMessage(this, message, this.labels.commonSuccess, this.labels.commonSuccess);
    }
    
}