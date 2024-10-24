import { LightningElement, track, api, wire } from "lwc";
import {
    LabelService,
    ErrorUtils,
    NotificationService,
    CommonUtils
} from "c/utils";
import { advanceSearchLabels } from './advanceReportSearchLabels';
import AdvanceReportSearchHelper from './advanceReportSearchHelper';
import { getRecord } from "lightning/uiRecordApi";
import getReportFilters from "@salesforce/apex/PaymentProposal.getReportFilters";
import setReportFilters from "@salesforce/apex/PaymentProposal.setReportFilters";
import saveReportNameToPPRecord from "@salesforce/apex/PaymentProposal.saveReportNameToPPRecord";
import updatePaymentProposalRecord from "@salesforce/apex/PaymentProposal.updatePaymentProposalRecord";
import basicSearch from "@salesforce/apex/PaymentProposal.basicSearch";
import createPPLinesForPayables from "@salesforce/apex/PaymentProposal.createPPLinesForPayables";
import getResultsTableColumnDetails from "@salesforce/apex/PaymentProposal.getResultsTableColumnDetails";
import { RefreshEvent } from 'lightning/refresh';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import PAYMENT_PROPOSAL_OBJECT from '@salesforce/schema/Payment_Proposal__c';
import getAllReports from '@salesforce/apex/PaymentProposal.getAllReports';
import getCurrencyISOCode from '@salesforce/apex/PaymentProposal.getCurrencyISOCode';

export default class AdvanceReportSearch extends LightningElement {
    labelFactory = { ...LabelService, ...advanceSearchLabels() };
    advanceSearchReportHelper = new AdvanceReportSearchHelper();

    @api recordId;

    @track filterDetails = [];
    @track reportName;
    @track basicFlds = this.advanceSearchReportHelper.fetchBasicSearchFields();
    @track operatorFields = this.advanceSearchReportHelper.fetchOperatorSearchFields();
    @track dateFields = this.advanceSearchReportHelper.fetchDateRelatedSearchFields();
    @track ppDateField = this.advanceSearchReportHelper.fetchPaymentProposalDateField();

    @track fields = this.advanceSearchReportHelper.fetchReportFields();
    @track error;
    @track isError;
    @track isAdvanceSearch = false;
    @track isShowSpinner;
    @track properties = {
        iconName: 'utility:info', iconTitle: 'Info',
        boxTheme: 'slds-theme_shade', boxTheme1: 'slds-theme_alert-texture',
        infoText: this.labelFactory.NO_FILTER_MSG
    };
    @track objectInfo = {};
    @track searchData;
    @track searcHistory = {current: '', prev: ''};
    @track reports;
    @track selectedReport;
    @track resultTableColumns;
    @track cloneSearchData;
    currencyISOCode;


    get searchDisabled() {
        if (this.isAdvanceSearch && this.reportName) {
            return false;
        } else if (!this.isAdvanceSearch) {
            return false;
        } else {
            return true;
        }
    }

    get resultLabel() {
        return this.labelFactory.COMMON_SMALL_RESULTS.charAt(0).toUpperCase() + this.labelFactory.COMMON_SMALL_RESULTS.slice(1);
    }

    get searchLabel() {
        return this.isAdvanceSearch ? this.labelFactory.ADVANCE_FILTER_SEARCH : this.labelFactory.BASIC_FILTER_SEARCH;
    }

    get isFilterAvailable() {
        return this.filterDetails.length > 0;
    }

    connectedCallback() {
        this.isShowSpinner = true;
       
    }

    renderedCallback() {
        try {
            if (!(this.isFilterAvailable) && this.isAdvanceSearch) {
                setTimeout(() => {
                    //query the infoBox class of accountingSeedInfoBox Html and then add theme in it
                    let childDiv = this.template.querySelector('.infoBox');
                    childDiv.classList.add(this.properties.boxTheme);
                    childDiv.classList.add(this.properties.boxTheme1);
                }, 100);
            }
        }
        catch (err) {
            NotificationService.displayToastMessage(this, err.message, this.labelFactory.commonToastErrorTitle + ':', this.labelFactory.commonErrorText);
        }
    }
    
    @wire(getObjectInfo, { objectApiName: PAYMENT_PROPOSAL_OBJECT })
    ppObjectInfo({ data, err }) {
        if (data) {
            this.basicFlds.map(item => {
                let fldSchema = data.fields[item.fieldApiName];
                this.objectInfo[item.fieldApiName] = fldSchema.dataType;
            });
        } else if (err) {
            NotificationService.displayToastMessage(
                this,
                JSON.stringify(err),
                this.labelFactory.ERR_IN_OBJ_DETAILS,
                this.labelFactory.commonErrorText
            );
        }
    }

    @wire(getRecord, {
        recordId: "$recordId",
        fields: "$fields",
    })
    fetchCommonRecord({ data, error }) {
        if (data) {
            this.getCurrencyISOCodeJS(this.recordId);
            const reptName = data.fields[this.fields[0].fieldApiName].value;
            this.isAdvanceSearch = data.fields[this.fields[1].fieldApiName].value;
            this.searcHistory.current =  this.isAdvanceSearch ? 'advance' : 'basic';
            this.searcHistory.prev =  this.searcHistory.prev !== '' ?  this.searcHistory.prev :  this.searcHistory.current;
            
            if(this.isAdvanceSearch){
                this.template.querySelector('[data-id="advanceSearchBtn"]').classList.add('slds-button_brand');
                this.template.querySelector('[data-id="basicSearchBtn"]').classList.add('slds-button_neutral');
                this.template.querySelector('[data-id="basicSearchBtn"]').classList.remove('slds-button_brand');

            } 
            let reptFilters = data.fields[this.fields[2].fieldApiName].value;
            this.reportName = reptName;
            this.getAllReports(reptFilters);
        } else if (error) {
            NotificationService.displayToastMessage(
                this,
                JSON.stringify(error),
                this.labelFactory.ERR_FILTER_MSG,
                this.labelFactory.commonErrorText
            );
        }
        if (this.searcHistory.current !== '' &&  this.searcHistory.prev !== '') {
            if( this.searcHistory.current !== this.searcHistory.prev){
                this.searchData = { columns: this.resultTableColumns, data: [] };
            }
        }

        if(!this.searchData){
            this.searchData = this.cloneSearchData;
        }
    }
    @wire(getResultsTableColumnDetails,{})
    getResultsTableColumnDetails({ error, data }) {
        if (data) {
            this.resultTableColumns = data;
            this.searchData = { columns: this.resultTableColumns, data: [] };  
            this.cloneSearchData = this.searchData;   
        } else if (error) {
            NotificationService.displayToastMessage(
                this,
                JSON.stringify(error),
                this.labelFactory.ERR_FILTER_MSG,
                this.labelFactory.commonErrorText
            );
        }
    }

    getCurrencyISOCodeJS(recordId) {
        getCurrencyISOCode({ recordId: recordId }).then((result) => {
            this.currencyISOCode = result;
        })
    }

    async getAllReports(reptFilters) {
        try {
            let result = await getAllReports();
            this.reports = result.map(({Name:label, Id:value}) =>({label, value}));
            this.selectedReport = (this.reports.find(({label}) => label === this.reportName)?.value);
            if (this.reportName !== null && this.isAdvanceSearch && this.filterDetails.length === 0) {
                this.filterDetails = [];
                this.fetchReportFilters(reptFilters);
            }
            else if(this.reportName === null && this.isAdvanceSearch){
                NotificationService.displayToastMessage(
                    this,
                    this.labelFactory.INFO_NO_REPORT_MSG,
                    this.labelFactory.COMMON_WARNING,
                    this.labelFactory.COMMON_WARNING
                );
            }
        }
        catch (err) {
            this.processError(err);
            NotificationService.displayToastMessage(
                this,
                this.error,
                this.labelFactory.ERR_GETTING_REPORT_NAMES,
                this.labelFactory.commonErrorText
            );
        }
        finally{
            this.isShowSpinner = false;
        }
    }

    countOccurrences(existingFilter, key) {
        let count = 0;
        if(existingFilter){
            count = existingFilter.split(key).length - 1;
        }
        return count;
    }

    async fetchReportFilters(existingFilters = null) {
        try {
            this.isShowSpinner = true;
            let result = await getReportFilters({ reportName: this.reportName });
            let fldMap = new Map(Object.entries(result));
            for (const key of fldMap.keys()) {
                let fldMapList = fldMap.get(key);
                for(let str of fldMapList){
                    let filterWithValue = str.split("&FILTER_VALUE_");
                    let currentFilterValueOfReport = filterWithValue[1];
                    if(fldMapList.length === this.countOccurrences(existingFilters,key)){
                        let strKey = key + ' ' +filterWithValue[0];
                        if(existingFilters && existingFilters.includes(strKey)){
                            let str = existingFilters.slice(existingFilters.indexOf(strKey) + strKey.length + 1);
                            currentFilterValueOfReport = ((str.split("\n"))[0]).trimStart();
                            let lines = str.split('\n');
                            existingFilters = lines.slice(1).join('\n');
                        }else{
                            currentFilterValueOfReport = filterWithValue[1];
                        }
                        fldMapList = fldMapList.filter(item => item !== str);
                    }
                    let reportFilterObject = {
                        initialReportColumnName: key,
                        reportColumnName: this.stripFieldQualifier(key),
                        operator: filterWithValue[0],
                        value: currentFilterValueOfReport,
                        };

                    this.filterDetails.push(reportFilterObject);
                }
            }
          } catch (err) {
                this.processError(err);
                NotificationService.displayToastMessage(
                    this,
                    this.error,
                    this.labelFactory.ERR_FROM_FILTER_DATABASE,
                    this.labelFactory.commonErrorText
                );
            }
            finally {
                this.isShowSpinner = false;
            }
    }

    processError(e) {
        let { isError, error } = ErrorUtils.processError(e);
        if (isError) {
            this.error = error;
            this.isError = isError;
        } else {
            this.error = error.toString();
            this.isError = true;
        }
    }

    handleValueChange(evt) { }

    handleLoad() {
        this.isShowSpinner = false;
    }

    async handleSearch() {
        this.isShowSpinner = true;

        this.searchData = undefined;

        if (this.isAdvanceSearch) {
            this.searcHistory.prev = 'advance';
            let vals = this.template.querySelectorAll('.filterValues');
            let filterVals = [];
            vals.forEach(item => {
                filterVals.push(item);
            });

            this.filterDetails = this.filterDetails.map(item => {
                let data = filterVals.filter(item1 => (item.reportColumnName === item1.dataset.ind));
                filterVals = filterVals.filter(item1 => {
                    return !(data[0].value === item1.value && item.reportColumnName === item1.dataset.ind && item.operator === item1.dataset.operator);
                });
                return { ...item, value: data[0].value };
            });

            try {

                let result = await setReportFilters({ filters: JSON.stringify(this.filterDetails), reptName: this.reportName, ppId: this.recordId });
                if (result && result.data && result.data.length > 0) {
                    this.searchData = result;                   
                    NotificationService.displayToastMessage(
                        this,
                        this.labelFactory.FILTER_SAVED_SUCCESS,
                        this.labelFactory.commonSuccess,
                        this.labelFactory.commonSuccess
                    );
                }
                else {              
                    NotificationService.displayToastMessage(
                        this,
                        this.labelFactory.NO_MATCHING_RECORD_FOUND,
                        this.labelFactory.COMMON_WARNING,
                        this.labelFactory.COMMON_WARNING
                    );
                }
                
            } catch (err) {
                this.processError(err);
                if (this.error.includes(this.labelFactory.INFO_NO_RECORD_MSG)) {
                    NotificationService.displayToastMessage(
                        this,
                        this.error,
                        this.labelFactory.COMMON_WARNING,
                        this.labelFactory.COMMON_WARNING
                    );
                }
                else {
                    NotificationService.displayToastMessage(
                        this,
                        this.error,
                        this.labelFactory.ERR_FILTER_SAVING,
                        this.labelFactory.commonErrorText
                    );
                }
            } finally {
                this.dispatchEvent(new RefreshEvent());
                this.isShowSpinner = false;
                if(!this.searchData){
                    this.searchData = this.cloneSearchData;
                }
            }
        }
        // to handle basic search
        else {
            this.handleBasicSearch();
        }
    }

    showColumns(){
        if(!this.searchData && this.searchData.data.length == 0){
            this.searchData = this.cloneSearchData;
        }
    }

    async handleBasicSearch() {
        this.searcHistory.prev = 'basic';
        let fldSchema = [...this.template.querySelectorAll('.inputFlds')];
        let fldObject = {};
        const allValid = fldSchema.reduce((validSoFar, item) => {
            fldObject[item.fieldName] = item.value;
            return validSoFar && (item.required ? item.value !== null : true);
        }, true);

        if (allValid) {
            try {
                let result = await basicSearch({ ppId: this.recordId, ppJSON: JSON.stringify(fldObject) });
                if (result && result.data && result.data.length > 0) {
                    this.searchData = result;
                }
                else{
                    NotificationService.displayToastMessage(
                        this,
                        this.labelFactory.NO_MATCHING_RECORD_FOUND,
                        this.labelFactory.COMMON_WARNING,
                        this.labelFactory.COMMON_WARNING
                    );
                }
                this.dispatchEvent(new RefreshEvent());
            } catch (err) {
                let exceptionName = 'FIELD_CUSTOM_VALIDATION_EXCEPTION';
                if ((err.body.message).includes(exceptionName)) {
                    let exceptionIndex = (err.body.message).indexOf(exceptionName);
                    let substringAfterException = (err.body.message).substring(exceptionIndex + exceptionName.length + 1);
                    err = (substringAfterException.includes(':'))?substringAfterException.split(':')[0]: substringAfterException;
                }
                this.processError(err);
                NotificationService.displayToastMessage(
                    this,
                    this.error,
                    this.labelFactory.ERR_IN_BASIC_SEARCH,
                    this.labelFactory.commonErrorText
                );
            } finally {
                this.isShowSpinner = false;
            }
        }
        else {
            this.isShowSpinner = false;
            this.showColumns();
        }
    }

    handleErrors(event) {
        NotificationService.displayToastMessage(this, event.detail.detail, this.labelFactory.commonToastErrorTitle + ':', this.labelFactory.commonErrorText);
    }

    handleRowSelection(evt) {
        let addButton = this.refs.addBtn;
        addButton.disabled = !(evt.detail.selectRows.length > 0);
    }

    async handleAdd() {
        this.isShowSpinner = true;
        try {
            let tableData = [...this.searchData.data];
            let tableCols = [...this.searchData.columns]
            let selectedRows = this.refs.searchTable?.getDatatable()?.getSelectedRows() || [];
            let selectedIds = [...selectedRows,].map(item => {
                return item.Id;
            });
            let result = await createPPLinesForPayables({ payableIds: JSON.stringify(selectedIds), ppId: this.recordId });
            this.searchData = undefined;
            if(result.length === 0)
            {
                NotificationService.displayToastMessage(
                    this,
                    this.labelFactory.ERR_PAYABLE_ON_HOLD_PPL,
                    this.labelFactory.commonErrorText,
                    this.labelFactory.commonErrorText
                );
            }
            else if(result.length > 0 && selectedIds.length != result.length)
            {
                NotificationService.displayToastMessage(
                    this,
                    this.labelFactory.INFO_PAYABLE_ON_HOLD_PPL,
                    this.labelFactory.commonSuccess,
                    this.labelFactory.commonSuccess
                );
            }
            else{
                NotificationService.displayToastMessage(
                    this,
                    this.labelFactory.PAYABLE_TO_LINES_MSG,
                    this.labelFactory.commonSuccess,
                    this.labelFactory.commonSuccess
                );

            }
            setTimeout(() => {
                this.searchData = { columns: [], data: [] };
                this.searchData.columns = tableCols;

                let insertedPayables = [...result,].map(item => {
                    return item.AcctSeed__Payable__c});

                    if (result.length === 0) {
                        this.searchData.data = [...tableData];
                    } else if (result.length > 0) {
                        this.searchData.data = tableData.length >= selectedRows.length ? tableData.filter(row => !(insertedPayables.includes(row.Id))) : undefined;
                    }

                if (this.searchData.data.length === 0) {
                    this.searchData = { columns: this.resultTableColumns, data: [] };
                }
            }, 1);
        }
        catch (err) {
            this.processError(err);
            NotificationService.displayToastMessage(
                this,
                this.error,
                this.labelFactory.ERR_IN_PAYABLE_TO_PPLINES,
                this.labelFactory.commonErrorText
            );
        } finally {
            this.isShowSpinner = false;
            let addButton = this.refs.addBtn;
            addButton.disabled = true;
            this.dispatchEvent(new RefreshEvent());
        }
    }

    handleReportChange(event) {
        this.searchData = undefined;
        this.selectedReport = event.detail.value;
        let reportName = (this.reports.find(({value}) => value === event.detail.value)?.label);
        this.saveReportName(reportName);
    }

    async saveReportName(reportName) {
        try {
            this.isShowSpinner = true;
            await saveReportNameToPPRecord({ ppId: this.recordId, reportName: reportName });
            NotificationService.displayToastMessage(
                this,
                this.labelFactory.REPORT_SAVED_SUCCESS,
                this.labelFactory.commonSuccess,
                this.labelFactory.commonSuccess
            );
            this.reportName = reportName;
            this.filterDetails = [];
        }
        catch (err) {
            this.processError(err);
            NotificationService.displayToastMessage(
                this,
                this.error,
                this.labelFactory.ERR_REPORT_SAVING,
                this.labelFactory.commonErrorText
            );
        } finally {
            this.searchData = this.cloneSearchData;
            this.isShowSpinner = false;
            this.dispatchEvent(new RefreshEvent());         
        }

    }

    stripFieldQualifier = (fieldApiName) => fieldApiName.replaceAll(CommonUtils.getPackageQualifier(fieldApiName), "");

    //Method called when Advance Search Toggle Button clicked 
    async handleToggleChange(event) {
        this.isShowSpinner = true;
        this.searchData = undefined;
            
        
        let fieldsUpdatedValue = new Map();
        if(event.target.name.includes("Advance")){
            this.isAdvanceSearch = true;
            this.template.querySelector('[data-id="basicSearchBtn"]').classList.remove('slds-button_brand');
            this.template.querySelector('[data-id="basicSearchBtn"]').classList.add('slds-button_neutral');
            this.template.querySelector('[data-id="advanceSearchBtn"]').classList.add('slds-button_brand');
        }else{
            this.isAdvanceSearch = false;
            this.template.querySelector('[data-id="advanceSearchBtn"]').classList.remove('slds-button_brand');
            this.template.querySelector('[data-id="basicSearchBtn"]').classList.add('slds-button_brand');
        }
        

        if (this.fields && this.fields[1]) {
            fieldsUpdatedValue.set(this.fields[1].fieldApiName, this.isAdvanceSearch);
        }
        if (fieldsUpdatedValue.size > 0) {
            try {
                let result = await updatePaymentProposalRecord({
                    ppId: this.recordId,
                    mapOfFieldApiNameAndVal: JSON.stringify(Object.fromEntries(fieldsUpdatedValue))
                });
                this.isAdvanceSearch = result[this.fields[1].fieldApiName];
            } catch (err) {
                this.processError(err);
                NotificationService.displayToastMessage(
                    this,
                    this.error,
                    this.labelFactory.commonErrorText,
                    this.labelFactory.commonErrorText
                );
            } finally {
                this.isShowSpinner = false;
                this.dispatchEvent(new RefreshEvent());
            }
        }
        this.searchData = this.cloneSearchData;
    }

}