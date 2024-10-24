import { api, track, wire, LightningElement } from 'lwc';
import { updateRecord,getRecord } from 'lightning/uiRecordApi';
import * as fsUtils from 'c/fieldSetUtils';
import XDataService from 'c/xDataService';
import { showToastMessage, xLabelService, reduceErrors } from 'c/xUtils';
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import CsvParser from 'c/csvParser';
import { loadScript } from 'lightning/platformResourceLoader';
import PARSER from '@salesforce/resourceUrl/accounting_resources';
import Labels from './labels';
import { LabelService } from 'c/utils';
import {
    registerRefreshContainer,
    unregisterRefreshContainer
} from "lightning/refresh";
import XRowService from 'c/xRowService';
import getConfigs from '@salesforce/apex/AccountingSettingsHelper.getConfigs';

export default class PaymentProposalLineManager extends LightningElement {

    labels = {...LabelService, ...Labels};

    @api childReference = 'AcctSeed__Payment_Proposal_Line__c.AcctSeed__Payment_Proposal__c';
    @api columnsForReadOnly = ['AcctSeed__Status__c','AcctSeed__Error__c'];
    @api recordId;
    @api objectApiName;
    @api columnFieldSet = 'AcctSeed__Aggregate_Payment_Proposal_Lines';
    @api drawerFieldSet;
    @api columns;
    @api defaultSorting;
    @api fieldToSort;
    @api intialRowCount;
    @api addRowCount;
    @api reOrderField = '';
    @api rowTemplate = '';
    @api rowChangeTemplate ='LocalPaymentProposalLineMutation';
    @track drawer;
    @track requiredColumns;
    @track rowNumberColumn = {};
    @track subGridColumns = {};
    @track subqueryRelationshipApiName = '';
    @track subgridParentApiName = '';
    totalRecordsCount;
    countQueryString;

    //sub grid variable
    @api subquerySObjectName;
    @api subqueryRelationshipName;
    @api subqueryRelationshipFieldset;

    @api showSave;
    @api showDelete;
    @api showCSV;
    @api enableCaching = false;
    @track data;
    @track recordErrors;
    @track objectFields;
    @track currentRecordData;
    objectInfo;
    childObjectApiName;
    hasDrawerFields = false;
    spinnerClass = 'slds-show';
    fieldSetColumns;
    soqlString;
    dataSvc = new XDataService();
    refreshContainerID;
    almRowService = new XRowService();
    hasRowChangeTemplate= false;

    @wire (getConfigs)
    configs;

    @wire(getRecord, { recordId: '$recordId', fields : '$objectFields'})
    getCurrentRecord({ data, error }) {
        if (data) {
            this.currentRecordData = data;
            if(this.currentRecordData.fields.AcctSeed__Aggregate_by_Payee__c.value){
                this.columnFieldSet = 'AcctSeed__Aggregate_Payment_Proposal_Lines';
                this.drawerFieldSet = null;
                this.subquerySObjectName = 'AcctSeed__Payment_Proposal_Line__c';
                this.subqueryRelationshipName = 'AcctSeed__Payment_Proposal_Lines_Child__r';
                this.subqueryRelationshipFieldset = 'AcctSeed__Detail_Payment_Proposal_Lines';
                this.subgridParentApiName = 'AcctSeed__Parent__c';
            }else{
                this.columnFieldSet = 'AcctSeed__Non_Aggregate_Payment_Proposal_Lines';
                this.setNullToExtras();
            }
            this.getData();
            this.refreshIfNoUnsavedData();
        }else{
            this.setNullToExtras();
        }
    }
    setNullToExtras(){
        this.drawerFieldSet = null;
        this.subquerySObjectName = null;
        this.subqueryRelationshipName = null;
        this.subqueryRelationshipFieldset = null;
        this.subGridColumns = null;
    }
    refreshIfNoUnsavedData() {
        const datatable = this.template.querySelector('c-x-data-table');
        datatable & datatable.refreshIfNoUnsavedChanges();
    }
    async connectedCallback() {
        this.objectFields = [this.objectApiName + '.Name'];
        this.objectFields.push(this.objectApiName + '.AcctSeed__Aggregate_by_Payee__c');
        this.showSave = true;
        this.showDelete = true;
        this.refreshContainerID = registerRefreshContainer(
            this.template.host,
            this.refreshTable.bind(this, {detail:{visibleRows:10, startRowIndex:0}}),
        );
    }

    disconnectedCallback() {
        unregisterRefreshContainer(this.refreshContainerID);
    }

    async getData() {
        try {
            let fsRequest = {
                sObjectName : this.childReference,
                mainFieldSetName : this.columnFieldSet,
                extraFieldSetName : this.drawerFieldSet,
                reOrderFieldName : this.reOrderField,
                subquerySObjectName : this.subquerySObjectName,
                subqueryRelationshipName : this.subqueryRelationshipName,
                subqueryRelationshipFieldset : this.subqueryRelationshipFieldset,
                filter : this.recordId
            };
            [this.fieldSetColumns, this.soqlString] = await Promise.all([
                fsUtils.getFieldSetColumns(JSON.stringify(fsRequest)),
                fsUtils.getQueryStr(JSON.stringify(fsRequest))
            ]);
            if (this.fieldSetColumns) {

                const readOnlyAggregateFields = ['AcctSeed__Amount__c', 'AcctSeed__Credit_Amount__c'];
                const modifiedColumns = [];
                for (let col of this.fieldSetColumns.mainColumns) {
                    if (this.columnsForReadOnly.includes(col.apiName)) {
                        const modifiedCol = { ...col, updateable: false };
                        modifiedColumns.push(modifiedCol);
                    } else if(this.currentRecordData.fields.AcctSeed__Aggregate_by_Payee__c.value
                            && readOnlyAggregateFields.includes(col.apiName)){
                        const modifiedCol = { ...col, updateable: false };
                        modifiedColumns.push(modifiedCol);
                    } else {
                        modifiedColumns.push(col);
                    }
                }
                this.columns = modifiedColumns;
                
                const subGridModifiedCols = [];
                for (let col of this.fieldSetColumns.subGridColumns) {
                    if (this.columnsForReadOnly.includes(col.apiName)) {
                        const modifiedCol = { ...col, updateable: false };
                        subGridModifiedCols.push(modifiedCol);
                    } else {
                        subGridModifiedCols.push(col);
                    }
                }
                this.subGridColumns = subGridModifiedCols;
                this.drawer = this.fieldSetColumns.extraColumns;
                this.rowNumberColumn = this.fieldSetColumns.rowNumberColumn
                this.requiredColumns = this.fieldSetColumns.requiredColumns;

                
                this.subqueryRelationshipApiName = this.fieldSetColumns.subqueryRelationshipName;
                this.subgridParentApiName = this.fieldSetColumns.subgridParentApiName;
                this.hasRowChangeTemplate = await this.almRowService.hasRowChangeTemplate(this.objectApiName);
                this.hasDrawerFields = this.drawerFieldSet === '' || this.fieldSetColumns.extraColumns.length === 0 ? false : true;
                this.soqlString = await fsUtils.getQueryStr(JSON.stringify(fsRequest));
                this.soqlString = this.soqlString.replace('WITH SECURITY_ENFORCED', ' AND AcctSeed__Parent__c = null WITH SECURITY_ENFORCED');
                this.countQueryString = await fsUtils.getCountQueryStr(JSON.stringify(fsRequest));
                this.totalRecordsCount = await this.dataSvc.countSoqlQuery(this.countQueryString);
                this.data = await this.dataSvc.soqlQuery(this.soqlString);
            }
        } catch (error) {
            this.globalError = error?.body?.message;
        } finally {
            this.spinnerClass = 'slds-hide';
        }
    }

    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    wiredObjectInfo(data, error) {
        if (data) {
            this.objectInfo = data;
            if (this.childReference) {
                this.childObjectApiName = this.childReference.substring(0, this.childReference.indexOf("."));
            }
        }
    }

    @wire(getObjectInfo, { objectApiName: '$childObjectApiName' })
    childObjectInfo;

    get nameField() {
        let fieldName = '';
        if (this.objectInfo.data) {
            this.objectInfo.data.nameFields.forEach(item => {
                if (this.objectInfo.data.fields[item].nameField) {
                    fieldName = this.objectApiName + '.' + item;
                }
            })
        }
        return fieldName;
    }
    get hasSubGridDetails(){
        return (this.subqueryRelationshipName !== null && this.subqueryRelationshipName !== undefined && this.subqueryRelationshipName !== '' &&
                this.subquerySObjectName !== null && this.subquerySObjectName !== undefined && this.subquerySObjectName !== '');
    }
    get ldvEnabled () {
        return this.configs?.data?.enablements?.largeDataVolumeModeEnabled;
    }
    handleAction(evt) {
        switch (evt.detail.actionName) {
            case 'save':
                this.saveData(evt);
                break;
            case 'csv':
                this.csvExport(evt);
                break;
            case 'refresh':
                this.refreshTable(evt);
            default:
                console.error(Labels.ERR_NO_ACTION_BINDING_FOUND);
        }
    }
    async refreshTable(evt) {
        this.spinnerClass = 'slds-show';
        this.data = await this.dataSvc.soqlQuery(this.soqlString);
        this.doMovePage(evt);
        this.spinnerClass = 'slds-hide';
    }
    doMovePage(evt){
        if(this.data){
            let totalPages = Math.max(Math.ceil(this.data.length/evt.detail.visibleRows), 1) - 1;
            if((totalPages*evt.detail.visibleRows) < evt.detail.startRowIndex){
                let dataTable = this.template.querySelector('c-x-data-table');
                if(dataTable){
                    dataTable.afterSave(1);
                }
            }
        }
    }
    async saveData(evt) {
        let ref = this;
        try {
            this.spinnerClass = 'slds-show';
            const parentField = this.childReference.split('.')[1];
            for(let row of evt.detail.data){
                if(row[this.subqueryRelationshipName]){
                    for(let subRow of row[this.subqueryRelationshipName]){
                        if(!subRow[parentField]){
                            subRow[parentField] = this.recordId;
                        }
                    }
                }
            }
            let response = await this.dataSvc.upsertSObjectData(JSON.stringify(this.prepareDataWithChildRelationship(evt.detail.data)),
                            JSON.stringify(this.prepareDataWithChildRelationship(evt.detail.dataToDelete)),
                            this.subqueryRelationshipApiName, this.subgridParentApiName,
                            JSON.stringify(evt.detail.subgridDataToDelete));
            if (response.hasError || evt.detail.dataHasErrors) {
                let tempResponse = JSON.parse(JSON.stringify(response));
                tempResponse['allRecords'] = await this.dataSvc.soqlQuery(this.soqlString);
                this.recordErrors = tempResponse;
            } else {
                this.data = await this.dataSvc.soqlQuery(this.soqlString);
                updateRecord({ fields: { Id: this.recordId } });
                showToastMessage(ref, xLabelService.commonSuccess, xLabelService.dataSavedSuccessfully, 'success');
                this.doMovePage(evt);
            }
            this.spinnerClass = 'slds-hide';
        } catch (err) {
            this.spinnerClass = 'slds-hide';
            showToastMessage(ref, xLabelService.commonToastErrorTitle, xLabelService.dataNotSavedSuccessfully + ' - ' + reduceErrors(err), 'error');
        }
    }
    prepareDataWithChildRelationship(lines){
        if(this.hasSubGridDetails){
            lines = lines.map(row => row = this.manageChildRelationships(row,false));
        }
        return lines;
    }
    async csvExport(evt) {
        let allColumns = this.getAllColumns();

        let dataToExport = [];
        //strip out all the parent relationship objects
        const flatData = evt.detail.data.map(row => {
            let tempObj = {};
            for (const prop of Object.keys(row)) {
                if (typeof row[prop] !== 'object') {
                    let col = allColumns.get(prop);
                    if(!col){continue;}
                    if(col.type === 'reference'){
                        tempObj[col.label] =  row[col.typeAttributes.label.lookupApi].Name;
                        tempObj[col.label + ' ID'] =  row[prop];
                    }else{
                        tempObj[col.label] =  row[prop];
                    }
                }
            }
            tempObj['Id'] = row['Id'];
            dataToExport.push(tempObj);
        });
        const dataColumns = new Set();
        dataToExport.map(tempData => {
            for(const prop of Object.keys(tempData)){
                dataColumns.add(prop);
            }
        });
        await loadScript(this, PARSER + '/javascript/papaparse.min.js');
        const parser = new CsvParser(Papa);
        const csvData = parser.jsonToCsvUnparse({data : dataToExport, columns : Array.from(dataColumns)});

        let downloadElement = document.createElement('a');
        downloadElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(csvData);
        downloadElement.target = '_self';
        let dt = new Date();
        let nameForm = dt.getFullYear()+''+((dt.getMonth()+1) < 10 ? '0'+(dt.getMonth()+1)  : (dt.getMonth()+1)) +''+(dt.getDate() < 10 ? '0'+dt.getDate()  : dt.getDate())+'_'+dt.getHours()+'_'+dt.getMinutes();
        downloadElement.download = this.currentRecordData.fields.Name.value + '_Export_' + nameForm + '.csv';
        document.body.appendChild(downloadElement);
        downloadElement.click();
    }
    getAllColumns(){
        let mColumns = [];
        mColumns = this.columns.reduce( (map, column) => {
            map.set(column.apiName, column);
            return map;
        }, new Map());

        if(this.drawer.length > 0){
            mColumns =  this.drawer.reduce( (map, column) => {
                map.set(column.apiName, column);
                return map;
            }, mColumns);
        }

        if(Object.keys(this.rowNumberColumn).length > 0){
            mColumns.set(this.rowNumberColumn.apiName,this.rowNumberColumn);
        }

        return mColumns;
    }
    handleAddRow(evt) {
        this.newRowHelper(this.ldvEnabled ? [] : evt.detail.lines, evt.detail.isLoad);
    }
    newRowHelper(lineRecords, isLoad) {
        let lines = this.removeExtraKeys(lineRecords);
        let relationshipName = this.getRelationshipName();
        let state = this.getState(lines,relationshipName);
        this.createRows(state,isLoad);
    }
    removeExtraKeys(lines) {
        let cleanLines = [];
        lines.forEach(item => {
            item = this.removeUnwantedKeys(item,false);
            cleanLines.push(item);
        });
        return cleanLines;
    }
    getRelationshipName() {
        let relationshipName = this.objectInfo.data.childRelationships.filter(item =>{
            return item.childObjectApiName === this.childReference.split('.')[0];
        });
        return (relationshipName[0].fieldName ? relationshipName[0].fieldName : '');
    }
    getState(lines,relationshipName) {
        let state = {
            lines: lines, headerId: this.recordId,
            linesObjectApiName: this.childObjectApiName, headerObjectApiName: this.objectApiName,
            parentRelationshipApiName: relationshipName
        };
        return state;
    }
    async createRows(state,isLoad) {
        try {
            this.spinnerClass = 'slds-show';
            state.createRowsCount = isLoad ? this.intialRowCount || 1 : this.addRowCount || 1;
            let response = await this.almRowService.createRows(JSON.stringify(state), this.rowTemplate,this.enableCaching);
            const datatable = this.template.querySelector('c-x-data-table');
            datatable & datatable.handleAddRowActionResponse(response,isLoad);
        } catch (err) {
            this.globalError = err?.body?.message;
        } finally{
            this.spinnerClass = 'slds-hide';
        }
    }
    handleRowChange(evt){
        let row = evt.detail.updatedRow;
        let prevRow = evt.detail.oldRow;

        if(row[this.subqueryRelationshipName]){
            let currentBalance = 0;
            let creditApplied = 0;
            let totalPaid = 0;
            let totalDiscount = 0;
            row[this.subqueryRelationshipName].forEach((subRow,index)=>{
                const newAmount = this.getValueOrZero(subRow?.AcctSeed__Amount__c);
                const oldAmount = this.getValueOrZero(prevRow[this.subqueryRelationshipName][index]?.AcctSeed__Amount__c);
                
                const discount = this.getValueOrZero(subRow?.AcctSeed__Discount_Amount__c) - this.getValueOrZero(prevRow[this.subqueryRelationshipName][index]?.AcctSeed__Discount_Amount__c);
                subRow.AcctSeed__Current_Balance__c = this.getValueOrZero(subRow?.AcctSeed__Current_Balance__c) - discount;
                subRow.AcctSeed__Amount__c = newAmount !== oldAmount ? newAmount :  newAmount - discount + this.getValueOrZero(subRow?.AcctSeed__Credit_Amount__c);
                
                currentBalance += subRow.AcctSeed__Current_Balance__c > 0 ? subRow.AcctSeed__Current_Balance__c : 0;
                creditApplied += newAmount < 0 ? newAmount : 0;
                totalPaid += subRow.AcctSeed__Amount__c > 0 ? subRow.AcctSeed__Amount__c : 0;
                totalDiscount += discount > 0 ?  discount : 0;
            })
            row.AcctSeed__Current_Balance__c = currentBalance;
            row.AcctSeed__Credit_Amount__c = creditApplied;
            row.AcctSeed__Amount__c = totalPaid + row.AcctSeed__Credit_Amount__c;
        }
        row.AcctSeed__Current_Balance__c = this.getValueOrZero(row?.AcctSeed__Current_Balance__c) - (this.getValueOrZero(row?.AcctSeed__Discount_Amount__c) - this.getValueOrZero(prevRow?.AcctSeed__Discount_Amount__c));
        row.AcctSeed__Amount__c = this.getValueOrZero(row?.AcctSeed__Amount__c) + this.getValueOrZero(row?.AcctSeed__Credit_Amount__c) - (this.getValueOrZero(row?.AcctSeed__Discount_Amount__c) - this.getValueOrZero(prevRow?.AcctSeed__Discount_Amount__c));

        const datatable = this.template.querySelector('c-x-data-table');
        datatable & datatable.handleRowChangeResponse(row, evt.detail.updatedRow.rowKey);
    }
    getValueOrZero(val){
        return val ? Number(val) : 0;
    }
    async updateALMRow(evt){
        try {
            this.spinnerClass = 'slds-show';
            let rowKey = evt.detail.updatedRow.rowKey;
            let rowChangeRequest = {oldRow : this.removeUnwantedKeys(evt.detail.oldRow,false), updatedRow: this.removeUnwantedKeys(evt.detail.updatedRow,false),headerObjectApiName:this.objectApiName};
            let response = await this.almRowService.updateRow(JSON.stringify(rowChangeRequest), this.rowChangeTemplate);
            const datatable = this.template.querySelector('c-x-data-table');
            datatable & datatable.handleRowChangeResponse(response,rowKey);
        } catch (err) {
            this.globalError = err?.body?.message;
        } finally{
            this.spinnerClass = 'slds-hide';
        }
    }
    removeUnwantedKeys(line,needKeys) {
        let keysToIgnore = ['_selected', '_drawer', 'rowKey', '_updated', 'inEditMode', '_row','_hasSubgrid','hasError','message','childRowKeys'];
        return this.manageChildRelationships(Object.keys(line).filter(key =>
                    !keysToIgnore.includes(key)).reduce((obj, key) => {
                        obj[key] = line[key];
                        return obj;
                    }, {}
                ), needKeys);
    }
    manageChildRelationships(obj,needKeys){
        if(obj[this.subqueryRelationshipApiName] && obj[this.subqueryRelationshipApiName].length > 0){
            let tempObj = Object.assign([],obj[this.subqueryRelationshipApiName]);
            let replaceableObj = { "totalSize": tempObj.length, "done": true, "records": needKeys ? tempObj : this.removeExtraKeys(tempObj)};
            obj[this.subqueryRelationshipApiName] = replaceableObj;
        }
        return obj;
    }
};