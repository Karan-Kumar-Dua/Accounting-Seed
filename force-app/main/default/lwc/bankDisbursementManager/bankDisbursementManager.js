import { LightningElement, track, api, wire } from 'lwc';
import { LabelService, NotificationService } from "c/utils";
import CURRENCY from '@salesforce/i18n/currency';
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { bankDisbursementLabels } from './bankDisbursementManagerLabels';
import getCDandJELRecords from "@salesforce/apex/BankDisbursementManager.getCDandJELRecords";
import getTotalJELRecords from "@salesforce/apex/BankDisbursementManager.getTotalJELRecords";
import getTotalCDRecords from "@salesforce/apex/BankDisbursementManager.getTotalCDRecords";
import associateOrUnassociateRecords from "@salesforce/apex/BankDisbursementManager.updateCDorJELrecords";
import getBankDisbRecord from '@salesforce/apex/BankDisbursementManager.queryBankDisbursementRecord';
import DISBURSEMENT_DATE_FIELD from "@salesforce/schema/Bank_Disbursement__c.Disbursement_Date__c";
import AMOUNT_FIELD from "@salesforce/schema/Bank_Disbursement__c.Amount__c";
import { RefreshEvent } from 'lightning/refresh';

export default class BankDisbursementManager extends LightningElement {
    labelFactory = { ...LabelService, ...bankDisbursementLabels() };

    @api recordId;
    @track columns = [];
    @track resultData = [];
    @track clonedResultData = [];
    @track totalRecordsCount = 0;
    @track lastFetchedRecordId;
    currentTab = this.labelFactory.COMMON_ASSOCIATE;
    isShowSpinner = true;
    totalCDrecords = 0;
    totalJELrecords = 0;
    initialquerylimit = 2000;
    queryLimitForJEL = this.initialquerylimit;
    queryLimitForCD = this.initialquerylimit;
    recordsfetchedIteration = 0;
    objecttypeOptions = [];
    @track bankDisbursementRecord;
    @track clonedbankDisbursementRecord;
    displayFields = ['name', 'vendorName', 'objDate', 'amount', 'ledgerAmount', 'reference', 'sourceType'];
    @track currencyISOCode;

    constructor() {
        super(); 
        this.initializeColumns();
    }

    initializeColumns() {
        this.columns = [
            { label: this.labelFactory.COMMON_NAME, fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'name' }, target: '_blank' } },
            { label: this.labelFactory.COMMON_VENDOR, fieldName: 'vendorUrl', type: 'url', typeAttributes: { label: { fieldName: 'vendorName' }, target: '_blank' } },
            { label: this.labelFactory.RECORD_DATE_COL_FOR_BANKDISB_LWC, fieldName: 'objDate' },
            { label: this.labelFactory.COMMON_AMOUNT, fieldName: 'amount', type: 'text', cellAttributes: { alignment: 'right' } },
            { label: this.labelFactory.INF_LEDGER_AMOUNT, fieldName: 'ledgerAmount', type: 'text', cellAttributes: { alignment: 'right' } },
            { label: this.labelFactory.COMMON_REFERENCE, fieldName: 'reference' },
            { label: this.labelFactory.COMMON_TYPE, fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'sourceType' }, target: '_blank' } },
            { label: this.labelFactory.COMMON_VIEW, type: 'button', typeAttributes: { label: 'view', variant: 'base', name: 'view' } }
        ];
    }

    get amount() {
        const rawAmount = getFieldValue(this.bankDisbursementRecord, AMOUNT_FIELD);
        if (rawAmount !== null && rawAmount !== undefined) {
            return parseFloat(rawAmount).toFixed(2);
        }
        return rawAmount;
    }

    get disbursementDate() {
        return getFieldValue(this.bankDisbursementRecord, DISBURSEMENT_DATE_FIELD);
    }

    get hasMoreRecordsToLoad() {
        return !this.resultData || this.resultData.length < this.totalRecordsCount;
    }

    get errorMessageIfNoRecordsFound() {
        if(this.clonedbankDisbursementRecord && this.clonedbankDisbursementRecord.AcctSeed__Bank_Reconciliation__c && (this.resultData.length === 0 || this.currentTab == this.labelFactory.COMMON_UNASSOCIATE)){
            var errorMessage = this.formatString(this.labelFactory.ERR_PREVENT_ASSOCIATING_RECORD_IF_BANK_RECONCILIATION_CLEARED, this.labelFactory.COMMON_BANK_DISBURSEMENT,
                this.clonedbankDisbursementRecord.AcctSeed__Bank_Reconciliation__r.Name , this.labelFactory.COMMON_BANK_DISBURSEMENT);
            return errorMessage;
        }else if(this.resultData.length === 0){
            return this.labelFactory.NO_RECORDS_FOUND_LABEL_FOR_BANKDIS_MANAGER + ' ' + this.labelFactory.NO_RECORDS_FOUND_LABEL_FOR_BANKDIS_MANAGER;
        }
    }

    @wire(getRecord, { recordId: "$recordId", fields: [DISBURSEMENT_DATE_FIELD, AMOUNT_FIELD] })
    fetchCommonRecord({ data, error }) {
        if (data) {
            this.bankDisbursementRecord = data;
            this.setDefaultDates(this.disbursementDate);
            this.getBankDisbursementRecord();
        } else if (error) {
            this.showErrorNotification(JSON.stringify(error), this.labelFactory.ERR_FETCHING_BANKDIS_RECORD);
        }
    }

    async getCurrencyCode() {
        if (this.clonedbankDisbursementRecord.hasOwnProperty('CurrencyIsoCode')) {
            this.currencyISOCode = this.clonedbankDisbursementRecord.CurrencyIsoCode;
        }else{
            this.currencyISOCode = CURRENCY;
        }
        this.validateFields();
    }

    async connectedCallback() {
        await Promise.all([
            this.initializeObjectTypeOptions(),
            this.initializeCombobox()
        ]);
        if (this.resultData.length === 0 && this.currentTab === this.labelFactory.COMMON_ASSOCIATE) {
            this.currentTab = this.labelFactory.COMMON_UNASSOCIATE;
            this.handleSearch();
        }
    }

    async initializeObjectTypeOptions() {
        this.objecttypeOptions = [
            { label: this.labelFactory.COMMON_ALL_LABEL, value: this.labelFactory.COMMON_ALL_LABEL },
            { label: this.labelFactory.CASH_DISBURSEMENT_LABEL, value: this.labelFactory.CASH_DISBURSEMENT_LABEL },
            { label: this.labelFactory.JOURNAL_ENTRY_LINE_TYPE_LABEL, value: this.labelFactory.JOURNAL_ENTRY_LINE_TYPE_LABEL }
        ];
    }

    async initializeCombobox() {
        return new Promise(resolve => {
            setTimeout(async () => {
                const combobox = this.template.querySelector('lightning-combobox[data-id="objectType"]');
                if (combobox && this.objecttypeOptions.length > 0) {
                    combobox.value = this.objecttypeOptions[0].value;
                }
                await this.handleSearch()
                resolve(); 
            }, 1000);
        });
    }

    getBankDisbursementRecord(){
        getBankDisbRecord({ recordId: this.recordId }).then(data => {
            this.clonedbankDisbursementRecord = data[0];
            this.getCurrencyCode();
		})
		.catch(error => {
			this.showErrorNotification(JSON.stringify(error), this.labelFactory.ERR_FETCHING_BANKDIS_RECORD);
		})
    }

    setDefaultDates(disbursementDate) {
        if (!disbursementDate) return;
    
        const disbursementDateObj = new Date(disbursementDate);
        const startDateObj = new Date(disbursementDateObj);
        startDateObj.setDate(disbursementDateObj.getDate() - 30);
        
        const formatDate = date => date.toISOString().split('T')[0];
        
        this.template.querySelector('lightning-input[data-id="startDate"]').value = formatDate(startDateObj);
        this.template.querySelector('lightning-input[data-id="endDate"]').value = formatDate(disbursementDateObj);
    }

    async handleSearch() {
        try {
            this.resetSearchResults();
            const fldObject = this.buildFieldObject();
            if (this.validateFields()) {
                this.isShowSpinner = true;
                await this.getTotalNumberOfPages(fldObject);
                await this.fetchRecords(fldObject); 
            } else {
                this.isShowSpinner = false;
            }
        } catch (err) {
            this.showErrorNotification(JSON.stringify(err), this.labelFactory.ERR_IN_BANK_DISBURSEMENT_MANAGER_COMPONENT);
        } finally {
            this.isShowSpinner = false;
            await this.moveToPageNumber(0);
            this.dispatchEvent(new RefreshEvent());
        }
    }

    resetSearchResults() {
        this.resultData = [];
        this.lastFetchedRecordId = '';
        this.queryLimitForCD = this.initialquerylimit;
        this.queryLimitForJEL = this.initialquerylimit;
        this.recordsfetchedIteration = 1;
    }

    buildFieldObject() {
        const fldObject = {};
        this.template.querySelectorAll('.inputFlds').forEach(item => {
            fldObject[item.dataset.id] = item.value;
        });
        fldObject['queryLimitForCD'] = this.queryLimitForCD;
        fldObject['queryLimitForJEL'] = this.queryLimitForJEL;
        return fldObject;
    }

    validateFields() {
        const fields = [...this.template.querySelectorAll('.inputFlds')];
        const allValid = fields.every(item => item.checkValidity());
        try{
            if (!allValid) {
                fields.forEach(item => {
                    if (!item.checkValidity()) {
                        item.reportValidity();
                    }
                });
            } else {
                fields.forEach(item => {
                    if (item.checkValidity()) {
                        item.setCustomValidity('');
                        item.reportValidity();
                    }
                });
            }
        } catch (err) {
            this.showErrorNotification(JSON.stringify(err), this.labelFactory.ERR_IN_BANK_DISBURSEMENT_MANAGER_COMPONENT);
        } finally {
            this.dispatchEvent(new RefreshEvent());
        }
        return allValid;
    }
    
    async fetchRecords(fldObject) {
        const result = await getCDandJELRecords({ bankDisbursementId: this.recordId, filtersJSON: JSON.stringify(fldObject), currentTabVal: this.currentTab });
        this.processFetchedRecords(result);
    }

    processFetchedRecords(result) {
        if (result && result.length > 0) {
            this.resultData = result.map(record => this.mapRecord(record));
            this.lastFetchedRecordId = this.resultData[this.resultData.length - 1].sourceObj.sourceId;
            this.clonedResultData = this.resultData;
        }
    }

    mapRecord(record) {
        const baseUrl = record.sourceObj.baseURL;
    
        const formatCurrency = (amount, currency) => {
            return `${currency} ${amount.toFixed(2)}`;
        };
    
        return {
            ...record,
            amount: formatCurrency(record.money.recordAmount, record.money.recordCurrency),
            ledgerAmount: formatCurrency(record.money.ledgerAmount, record.money.ledgerCurrency), 
            recordUrl: `${baseUrl}/${record.sourceObj.sourceId}`,
            vendorUrl: record.customerInfo.vendorId ? `${baseUrl}/${record.customerInfo.vendorId}` : '',
            vendorName: record.customerInfo.vendorName || '',
            sourceType: record.sourceObj.sourceType,
            sourceName: record.sourceObj.sourceName
        };
    }

    handleinputValueChange(event) {
        this.isShowSpinner = true;
        this.recordsfetchedIteration = 0;
        const searchKey = event.target.value.toLowerCase();
        clearTimeout(this.typingTimeout);
        this.typingTimeout = setTimeout(() => {
            if (searchKey) {
                this.lastFetchedRecordId = '';
                this.handleKeyChangeHelper(searchKey);
                this.isShowSpinner = false;
            } else {
                this.resultData = this.clonedResultData;
                this.isShowSpinner = false;
            }
        }, 300); 
    }
    
    async handleKeyChangeHelper(searchKey) {
        await this.loadMore(-1);
        this.filterResultData(searchKey);
    }
    
    async filterResultData(searchKey) {
        this.resultData = undefined;
       
        const simplifiedData = this.clonedResultData.map(record => ({
            original: record,
            simplified: this.mapToSimplifiedData(record)
        }));
        this.resultData= simplifiedData.filter(({ simplified }) => {
            return Object.entries(simplified).some(([field, value]) =>{
                if(field == 'amount' || field == "ledgerAmount"){
                    
                    return parseFloat(value.split(' ')[1]) === parseFloat(searchKey)
                }else{
                    return value.includes(searchKey)
                }
            })  
        }).map(({ original }) => original);
        this.moveToPageNumber(0);
    }    

    mapToSimplifiedData(record) {
        let simplified = {};
        this.displayFields.forEach(field => {
            simplified[field] = record[field] ? record[field].toString().toLowerCase() : '';
        });
        return simplified;
    }

    async handleButtonClick() {
        this.isShowSpinner = true;
        this.clonedResultData = [...this.resultData];
        try {
            const selectedRows = this.getSelectedRows();
            const selectedIds = this.extractIds(selectedRows);

            if(this.clonedbankDisbursementRecord && !this.clonedbankDisbursementRecord.AcctSeed__Bank_Reconciliation__c){
                const result = await associateOrUnassociateRecords({
                    listOfRecordIdsToUpdate: JSON.stringify(selectedIds),
                    bankDisbRecordId: this.recordId,
                    currentTabVal: this.currentTab
                });
                
                await this.updateResultData(result, selectedRows);
                this.handleNotification(result, selectedIds);
            }else{
                var errorMessage = this.formatString(this.labelFactory.ERR_PREVENT_ASSOCIATING_RECORD_IF_BANK_RECONCILIATION_CLEARED, this.labelFactory.COMMON_BANK_DISBURSEMENT,
                    this.clonedbankDisbursementRecord.AcctSeed__Bank_Reconciliation__r.Name , this.labelFactory.COMMON_BANK_DISBURSEMENT);
                this.showErrorNotification(errorMessage, this.labelFactory.ERR_IN_BANK_DISBURSEMENT_MANAGER_COMPONENT);
            }
        } catch (err) {
            this.showErrorNotification(JSON.stringify(err), this.labelFactory.ERR_IN_BANK_DISBURSEMENT_MANAGER_COMPONENT);
        } finally {
            this.isShowSpinner = false;
            this.toggleButtons();
            this.dispatchEvent(new RefreshEvent());
        }
    }
    
    getSelectedRows() {
        return this.refs.searchTable?.getDatatable()?.getSelectedRows() || [];
    }
    
    extractIds(rows) {
        return rows.map(item => item.sourceObj.sourceId);
    }
    
    handleNotification(result, selectedIds) {
        if (result.length > 0 && selectedIds.length !== result.length) {
            this.showErrorNotification( this.labelFactory.ERR_IN_BANK_DISBURSEMENT_MANAGER_COMPONENT, this.labelFactory.ERR_IN_BANK_DISBURSEMENT_MANAGER_COMPONENT);
        } else {
            const successMessage = this.currentTab === this.labelFactory.COMMON_UNASSOCIATE
                ? this.labelFactory.SUCCESS_MSG_AFTER_ASSOCIATED_RECS_ON_BANKDISB_LWC
                : this.labelFactory.SUCCESS_MSG_AFTER_UNASSOCIATED_RECS_ON_BANKDISB_LWC;
            
            this.showSuccessNotification(successMessage);
        }
    }
    
    async updateResultData(result, selectedRows) {
        const fldObject = this.buildFieldObject();
        //await this.getTotalNumberOfPages(fldObject);
        const associatedRecs = result.map(item => item.Id);
        if (result.length === 0) {
            this.resultData = this.clonedResultData;
        } else if (result.length > 0) {
            if (this.clonedResultData.length >= selectedRows.length) {
                this.resultData = this.clonedResultData.filter(row => !(associatedRecs.includes(row.sourceObj.sourceId)));
            } else {
                this.resultData = undefined;
            }
        }
        
        if (this.resultData.length === 0) {
            this.resultData = [];
        }
    }
    
    toggleButtons() {
        const associateSelectedBtn = this.template.querySelector('[data-id="associateSelectedBtn"]');
        const unassociateSelectedBtn = this.template.querySelector('[data-id="unassociateSelectedBtn"]');
        
        associateSelectedBtn.disabled = true;
        unassociateSelectedBtn.disabled = true;
    }     

    async calculateQueryLimitForObjects() {   
        this.queryLimitForCD = this.initialquerylimit;
        this.queryLimitForJEL = this.initialquerylimit;

        const totalCDrecords = parseInt(this.totalCDrecords, 10) || 0;
        const totalJELrecords = parseInt(this.totalJELrecords, 10) || 0;
        const recordsfetchedIteration = parseInt(this.recordsfetchedIteration, 10) || 0;
        const initialQueryLimit = parseInt(this.initialquerylimit, 10) || 0;

        let remainingCDrecs = (totalCDrecords > ((recordsfetchedIteration - 1) * initialQueryLimit)) 
            ? totalCDrecords - ((recordsfetchedIteration - 1) * initialQueryLimit) 
            : 0;

        let remainingJELrecs = (totalJELrecords > ((recordsfetchedIteration - 1) * initialQueryLimit)) 
            ? totalJELrecords - ((recordsfetchedIteration - 1) * initialQueryLimit) 
            : 0;

        if((remainingCDrecs > this.initialquerylimit || remainingJELrecs > this.initialquerylimit) && 
            (remainingCDrecs + remainingJELrecs > 2* this.initialquerylimit)){
                if(remainingCDrecs > this.initialquerylimit){
                    this.queryLimitForCD = this.initialquerylimit;
                }else{
                    this.queryLimitForCD = remainingCDrecs;
                }
                if(remainingJELrecs > this.initialquerylimit){
                    this.queryLimitForJEL = this.initialquerylimit;
                }else{
                    this.queryLimitForJEL = remainingJELrecs;
                }
        }else{
            this.queryLimitForCD = remainingCDrecs;
            this.queryLimitForJEL = remainingJELrecs;
        }  
    }
    
    async getTotalNumberOfPages(fldObject) {
        try {
            this.totalCDrecords = await this.fetchTotalRecordsCount(getTotalCDRecords, fldObject, this.labelFactory.CASH_DISBURSEMENT_LABEL);
            this.totalJELrecords = await this.fetchTotalRecordsCount(getTotalJELRecords, fldObject, this.labelFactory.JOURNAL_ENTRY_LINE_TYPE_LABEL);
            this.totalRecordsCount = this.totalCDrecords + this.totalJELrecords;
        } catch (error) {
            this.showErrorNotification(error, this.labelFactory.ERR_IN_BANK_DISBURSEMENT_MANAGER_COMPONENT);
        }
    }

    async fetchTotalRecordsCount(apexMethod, fldObject, filterType) {
        fldObject.filterType = filterType;
        return apexMethod({ bankDisbursementId: this.recordId, filtersJSON: JSON.stringify(fldObject), currentTabVal : this.currentTab })
            .then(result => parseInt(result, 10))
            .catch(error => {
                this.showErrorNotification(error, this.labelFactory.ERR_IN_BANK_DISBURSEMENT_MANAGER_COMPONENT);
                return 0;
            });
    }

    async loadMore(offset) {
        let _data = [];
        this.isShowSpinner = true;
        try {
            this.calculateQueryLimitForObjects();
            const fldObject = this.buildFieldObject();
            fldObject['lastFetchedRecordId'] = this.lastFetchedRecordId;
            if (this.validateFields()) {
                this.recordsfetchedIteration += 1;
                const result = await getCDandJELRecords({ bankDisbursementId: this.recordId, filtersJSON: JSON.stringify(fldObject), currentTabVal: this.currentTab });
                if (result && result.length > 0) {
                    _data = result.map(record => this.mapRecord(record));
                    this.resultData = this.lastFetchedRecordId ? this.resultData : [];
                    
                    const combinedData = [...this.resultData, ..._data];

                    const uniqueNames = new Set();

                    this.resultData = combinedData.filter(item => {
                        if (!uniqueNames.has(item.name)) {
                            uniqueNames.add(item.name);
                            return true; 
                        }
                        return false; 
                    });

                    this.lastFetchedRecordId = this.resultData[this.resultData.length - 1].sourceObj.sourceId;
                        
                    if (this.resultData.length < this.totalRecordsCount) {
                        await this.loadMore(offset);
                    } else if (offset >= 0) {
                        this.moveToPageNumber(offset);
                    }
                    this.clonedResultData = [...this.resultData];
                }
            } else {
                this.isShowSpinner = false;
            }
        } catch (error) {
            this.showErrorNotification(error, this.labelFactory.ERR_IN_BANK_DISBURSEMENT_MANAGER_COMPONENT);
        } finally {
            this.isShowSpinner = false;
        }
    }
    
    handleTabChange(evt){
        this.toggleButtons();
        this.currentTab = evt.target.dataset.id;
        this.resultData = [];
        this.clonedResultData = []; 
        this.queryLimitForCD = this.initialquerylimit;
        this.queryLimitForJEL = this.initialquerylimit;
        this.lastFetchedRecordId = '';
        if(this.currentTab == this.labelFactory.COMMON_ASSOCIATE){
            this.handleSearch();
        }
    }

    handleLoadMoreRecords(evt){
        this.recordsfetchedIteration = 2;
        this.loadMore(evt.detail.offset);
    }

    handleRowSelection(evt) {
        let selectAssociateButton = this.template.querySelector('[data-id="associateSelectedBtn"]');
        let selectUnAssociateButton = this.template.querySelector('[data-id="unassociateSelectedBtn"]');
        if(this.currentTab == this.labelFactory.COMMON_UNASSOCIATE){
            selectAssociateButton.disabled = !(evt.detail.selectRows.length > 0);
        }else if(this.currentTab == this.labelFactory.COMMON_ASSOCIATE){
            selectUnAssociateButton.disabled = !(evt.detail.selectRows.length > 0);
        }
    }

    formatString(template, ...values) {
        return template.replace(/{(\d+)}/g, function(match, number) { 
            return typeof values[number] !== 'undefined'
                ? values[number]
                : match;
        });
    }

    async moveToPageNumber(offset) {
        let dataTable = this.template.querySelector('c-bank-disb-search-result-data-table');
        if (dataTable) {
            await Promise.resolve();
            if (offset >= 0) {
                dataTable.moveToPage(offset);
            } else {
                dataTable.moveToPage(1);
            }
        }
    }

    showErrorNotification(message, title) {
        NotificationService.displayToastMessage(this, message, title, this.labelFactory.commonErrorText);
    }

    showSuccessNotification(message) {
        NotificationService.displayToastMessage(this, message, this.labelFactory.commonSuccess, this.labelFactory.commonSuccess);
    }

    handleAmountChange(event) {
        const amountInput = event.target;
        const value = parseFloat(amountInput.value);
        const maxAmount = 1000000000;
    
        if (value > maxAmount) {
            amountInput.setCustomValidity(this.labelFactory.ERR_BANK_DISB_LWC_COMP_IF_AMOUNT_EXCEEDS);
        } else {
            amountInput.setCustomValidity('');  
        }
    
        amountInput.reportValidity();
    }
    
}