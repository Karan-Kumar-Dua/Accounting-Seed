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

export default class XLineManager extends LightningElement {

    labels = {...LabelService, ...Labels};

    @api childReference
    @api recordId;
    @api objectApiName;
    @api columnFieldSet;
    @api drawerFieldSet;
    @api columns;
    @api defaultSorting;
    @api fieldToSort;
    @api intialRowCount;
    @api addRowCount;
    @api reOrderField = '';
    @api rowTemplate = '';
    @api rowChangeTemplate ='';
    @track drawer;
    @track requiredColumns;
    @track rowNumberColumn = {};
    @track subGridColumns = {};
    @track subqueryRelationshipApiName = '';
    @track subgridParentApiName = '';

    //sub grid variable
    @api subquerySObjectName;
    @api subqueryRelationshipName;
    @api subqueryRelationshipFieldset;

    @api showSave;
    @api showDelete;
    @api showCSV;
    @api enableCaching = false;
    @track data;
    @track copyOfData = [];
    @track recordErrors;
    @track objectFields;
    @track currentRecordData;
    objectInfo;
    childObjectApiName;
    hasDrawerFields = false;
    spinnerClass = 'slds-show';
    fieldSetColumns;
    soqlString;
    countQueryString;
    totalRecordsCount = 0;
    recordsLimit = 5000;
    lastFetchedRecordId;
    rowsFilter;
    dataSvc = new XDataService();
    refreshContainerID;
    almRowService = new XRowService();
    hasRowChangeTemplate= false;
    @track promiseResponse = [];

    @wire (getConfigs)
    configs;

    @wire(getRecord, { recordId: '$recordId', fields : '$objectFields'})
    getCurrentRecord({ data, error }) {
        if (data) {
            this.currentRecordData = data;
            this.refreshIfNoUnsavedData();
        }
    };
    refreshIfNoUnsavedData() {
        const datatable = this.template.querySelector('c-x-data-table');
        datatable && datatable.refreshIfNoUnsavedChanges();
    }
    async connectedCallback() {
        await this.getData(); 
        await this.loadRecords();
        this.objectFields = this.objectApiName + '.Name';
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
            this.rowsFilter = this.recordId;
            let fsRequest = {
                    sObjectName : this.childReference, 
                    mainFieldSetName : this.columnFieldSet, 
                    extraFieldSetName : this.drawerFieldSet,
                    reOrderFieldName : this.reOrderField,
                    subquerySObjectName : this.subquerySObjectName,
                    subqueryRelationshipName : this.subqueryRelationshipName,
                    subqueryRelationshipFieldset : this.subqueryRelationshipFieldset,
                    filter : this.rowsFilter,
                    recordsLimit : this.recordsLimit,
                    orderByField : 'Id',
                    orderByDir : null
            };
            [this.fieldSetColumns, this.soqlString,this.countQueryString] = await Promise.all([
                fsUtils.getFieldSetColumns(JSON.stringify(fsRequest)),
                fsUtils.getQueryStr(JSON.stringify(fsRequest)),
                fsUtils.getCountQueryStr(JSON.stringify(fsRequest))
            ]);
            if (this.fieldSetColumns) {
                this.columns = this.fieldSetColumns.mainColumns;
                this.drawer = this.fieldSetColumns.extraColumns;
                this.rowNumberColumn = this.fieldSetColumns.rowNumberColumn
                this.requiredColumns = this.fieldSetColumns.requiredColumns;
                this.subGridColumns = this.fieldSetColumns.subGridColumns;
                this.subqueryRelationshipApiName = this.fieldSetColumns.subqueryRelationshipName;
                this.subgridParentApiName = this.fieldSetColumns.subgridParentApiName;
                this.hasRowChangeTemplate = await this.almRowService.hasRowChangeTemplate(this.objectApiName);
                this.hasDrawerFields = this.drawerFieldSet === '' || this.fieldSetColumns.extraColumns.length === 0 ? false : true;
                this.soqlString = await fsUtils.getQueryStr(JSON.stringify(fsRequest));
                this.countQueryString = await fsUtils.getCountQueryStr(JSON.stringify(fsRequest));
                this.totalRecordsCount = await this.dataSvc.countSoqlQuery(this.countQueryString); 
                this.copyOfData = [];
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
        this.lastFetchedRecordId = '';
        this.copyOfData = [];
        await this.getData();
        await this.loadRecords();
        this.doMovePage(evt);
        this.spinnerClass = 'slds-hide';
    }
    doMovePage(evt){
        if(this.data){
            let dataTable = this.template.querySelector('c-x-data-table');
            dataTable && dataTable.afterSave(1);
        }
    }
    async saveData(evt) {
        let ref = this;
        try {
            this.spinnerClass = 'slds-show';
            let dataArray = this.getDataArray(evt.detail.data);
            
            this.promiseResponse = [];
            await this.saveChanges(dataArray,evt,0);

            let response = {hasError : false, recordErrors : {}, successRecords : {}, records : []};
            if(this.promiseResponse && this.promiseResponse.length > 0){
                this.promiseResponse.forEach(item => {
                    if(item.hasError){
                        response.hasError = item.hasError;
                    }
                    response.recordErrors = item.recordErrors ? {...response.recordErrors, ...item.recordErrors} : response.recordErrors;
                    response.successRecords = item.successRecords ? {...response.successRecords, ...item.successRecords} : response.successRecords;
                    response.records = item.records ? [...response.records, ...item.records] : response.records;
                })
            }

            this.lastFetchedRecordId='';
            this.totalRecordsCount = await this.dataSvc.countSoqlQuery(this.countQueryString);
            await this.loadRecords();

            if (response.hasError || evt.detail.dataHasErrors) {
                let tempResponse = JSON.parse(JSON.stringify(response));
                tempResponse['allRecords'] = this.data;
                this.recordErrors = tempResponse;
            } else {
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
    async saveChanges(dataArray, evt, currentIndex){
        if(dataArray.length === 0 && (evt.detail.dataToDelete.length > 0 || evt.detail.subgridDataToDelete.length > 0)){
            this.promiseResponse.push(await this.dataSvc.upsertSObjectData('', 
                JSON.stringify(this.prepareDataWithChildRelationship(evt.detail.dataToDelete)),
                this.subqueryRelationshipApiName, 
                this.subgridParentApiName,
                JSON.stringify(evt.detail.subgridDataToDelete)));
        }else{
            if(currentIndex === 0){
                this.promiseResponse.push(await this.dataSvc.upsertSObjectData(
                    JSON.stringify(this.prepareDataWithChildRelationship(dataArray[currentIndex])), 
                    JSON.stringify(this.prepareDataWithChildRelationship(evt.detail.dataToDelete)),
                    this.subqueryRelationshipApiName, 
                    this.subgridParentApiName,
                    JSON.stringify(evt.detail.subgridDataToDelete)));
            }else{
                this.promiseResponse.push(await this.dataSvc.upsertSObjectData(
                    JSON.stringify(this.prepareDataWithChildRelationship(dataArray[currentIndex])), 
                    '[]',
                    this.subqueryRelationshipApiName, 
                    this.subgridParentApiName,
                    '[]'));
            }
            currentIndex++;
            if(currentIndex < dataArray.length){
                await this.saveChanges(dataArray,evt,currentIndex);
            }
        }
    }
    getDataArray(evtData){
        let dataArray = [];
        if(evtData.length > 0){
            while(evtData.length > 0){
                dataArray.push(evtData.splice(0,500));
            }
        }
        return dataArray;
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
        this.updateALMRow(evt);
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
   
    async loadRecords(){
        this.spinnerClass = 'slds-show';
        let _data = [];
        let filter = this.rowsFilter + (this.lastFetchedRecordId ? "' AND Id > '" + this.lastFetchedRecordId : '');
        try {
            let fsRequest = {
                    sObjectName : this.childReference, 
                    mainFieldSetName : this.columnFieldSet, 
                    extraFieldSetName : this.drawerFieldSet,
                    reOrderFieldName : this.reOrderField,
                    subquerySObjectName : this.subquerySObjectName,
                    subqueryRelationshipName : this.subqueryRelationshipName,
                    subqueryRelationshipFieldset : this.subqueryRelationshipFieldset,
                    filter : filter,
                    recordsLimit : this.recordsLimit,
                    orderByField : 'Id',
                    orderByDir : null
            };
            this.soqlString = await fsUtils.getQueryStr(JSON.stringify(fsRequest)); 
            _data = await this.dataSvc.soqlQuery(this.soqlString);
            this.copyOfData = this.lastFetchedRecordId ? this.copyOfData : [];
            this.copyOfData = [...this.copyOfData, ..._data];
            this.lastFetchedRecordId = this.copyOfData.length !== 0 ? this.copyOfData[this.copyOfData.length - 1].Id : '';
            if(this.copyOfData.length < this.totalRecordsCount){
                await this.loadRecords();
            }else{
                this.data = JSON.parse(JSON.stringify(this.copyOfData));
            }
        } catch (error) {
            this.globalError = error?.body?.message;
        } finally {
            this.spinnerClass = 'slds-hide';
        }
    }
    get hasMoreRecordsToLoad(){
        if(this.data && this.data.length === this.totalRecordsCount){
            return false;
        }else if(this.data && this.data.length > this.totalRecordsCount){
            return false;
        }else{
            return true;
        }
    }
}