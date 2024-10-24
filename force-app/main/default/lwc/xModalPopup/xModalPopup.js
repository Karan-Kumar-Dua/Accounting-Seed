import { LightningElement, api, track,wire } from 'lwc';
import CsvParser from 'c/csvParser';
import { KnowledgeBase, LabelService } from 'c/utils';
import {getObjectInfo} from 'lightning/uiObjectInfoApi';
import { loadScript } from 'lightning/platformResourceLoader';
import PARSER from '@salesforce/resourceUrl/accounting_resources';
import modalUpload from './xModalPopupUpload.html';
import modalUploadFile from './xModalUploadFile.html';
import newTemplate from './xModalCreateNewTemplate.html';
import mappingTable from './xModalMappingTable.html';
import modalEdit from './xModalPopupEditRecord.html';
import modalRefreshWarning from './xModalRefreshWarning.html';
import modalExportWarning from './xModalExportWarning.html';
import modalMapFields from './xModalPopupMapFields.html';
import modalTemplates from './xModalPopupSelectTemplate.html';
import errorTable from './xModalPopupErrorTable.html';
import {idGenerator,xLabelService} from 'c/xUtils';

export default class XModalPopup extends LightningElement {
    labels = LabelService;
    @api openModal;
    @api actionButtonText;
    @api cancelButtonText;
    @api templateVisible;
    @api rowKey;
    @api objectName;
    @api importTemplates;
    @track fieldsMap = {};
    @track file;
    sObjectName = 'AcctSeed__Import_Template__c';
    userMapping = '_default';
    hasSelectedRecord;
    chooseMapping = false;
    hasMoreThanOneSavedMappings = false;
    showMappings = false;
    newMapping = false;
    childName = '';
    parentName = '';
    @track csvImportData;
    @track fields = [];
    data = [];
    _data = [];
    warningModalFromData = {};
    @track options = [];
    gen = idGenerator();

    @track importTemplateOptions = [];
    @track error='';
    @track helpText = 'slds-hide';
    @track mColumns;
    @track errorTableObj ={};
    allColumns;
    @track templateFields = [];
    row;
    undoHistory;
    uploadedFileName = '';
    spinnerClass = 'slds-show';

    tempHistory = [];

    @wire(getObjectInfo, { objectApiName: '$sObjectName' })
    fetchSObjectInfo({data}) {
        if(data){
            let tempFields = [];
            Object.keys(data.fields).forEach(item => {
                if(data.fields[item].updateable && data.fields[item].apiName !== 'CurrencyIsoCode'){
                    tempFields.push(data.fields[item].apiName);
                }
            });
            tempFields = tempFields.reverse();
            tempFields.splice(tempFields.indexOf('OwnerId'),1);
            tempFields.splice(1,0,'OwnerId');
            this.templateFields = tempFields;
        }
    }

    render(){
        switch(this.templateVisible){
            case 'uploadFile':
                return modalUpload;
            case 'editRecord':
                return modalEdit;
            case 'mapFields':
                return modalMapFields;
            case 'templates':
                return modalTemplates;
            case 'createTemplate':
                return newTemplate;
            case 'uploadFileModal':
                return modalUploadFile;
            case 'mapping':
                return mappingTable;
            case 'errortable':
                return errorTable;
            case 'warning':
                return modalRefreshWarning;
            case 'exportwarning':
                return modalExportWarning;
        }
    }
    renderedCallback(){
        let recordFields = this.template.querySelectorAll('lightning-input-field');
        if(recordFields && this.templateVisible === 'editRecord'){
            recordFields.forEach(item => {
                item.value = this.row[item.fieldName];
            });
        }
    }
    handleLoad(){
        let inputField = this.template.querySelectorAll('lightning-input-field');
        if(inputField){
            inputField.forEach(item => {
                if(item.fieldName === 'Name'){
                    item.value = this.uploadedFileName.substring(0,79);
                }
                if(item.fieldName === 'AcctSeed__Detail__c'){
                    item.value = this.childName;
                }
                if(item.fieldName === 'AcctSeed__Parent__c'){
                    item.value = this.parentName;
                }
            })
        }
    }
    @api closeModal() {
        this.openModal = false;
    } 
    @api showModal(data) {
        this.templateVisible = data.modalFor;
        this.spinnerClass = data.modalFor !== 'editRecord' ? 'slds-hide' : 'slds-show';
        this.actionButtonText = data.actionText;
        this.cancelButtonText = data.cancelText;
        this.row = data.row ? JSON.parse(JSON.stringify(data.row)) : null;
        let uniq = {};
        this.allColumns = data.allColumns ? data.allColumns.filter(obj => !uniq[obj.apiName] && (uniq[obj.apiName] = true)) : '';
        this.fields = data.fields ? data.fields : null; 
        this.fieldsMap = data.fieldsMap ? data.fieldsMap : null;
        this.prepareFieldsMap();
        this.undoHistory = data.undoHistory ? data.undoHistory : [];
        this.objectName = data.objectName ? data.objectName : null;
        this.importTemplates = data.importTemplates ? data.importTemplates : null;
        this.prepareImportTemplates();
        this.openModal = true;
    } 
    @api showModaForTemplate(data) {
        this.helpText = 'slds-hide';
        this.hasSelectedRecord = null;
        this.picklistValue = data.picklistValue ? data.picklistValue : null;
        this.hasSelectedRecord = this.picklistValue;
        this.file  = data.file ? data.file : null;
        this.templateVisible = data.modalFor;
        this.spinnerClass = data.modalFor !== 'editRecord' ? 'slds-hide' : 'slds-show';
        this.actionButtonText = data.actionText;
        this.cancelButtonText = data.cancelText;
        this.importTemplates = data.importTemplates ? data.importTemplates : null;
        this.prepareImportTemplates();
        this.mappingObj = data.mappingObj ? data.mappingObj : null;
        this.openModal = true;
    } 
    @api showCreateTemplate(data){
        this.templateVisible = data.modalFor;
        this.openModal = true;
        this.uploadedFileName = data.csvFileName ? data.csvFileName : '';
        this.childName = data.childName ? data.childName : '';
        this.parentName = data.parentName ? data.parentName : '';
        this.spinnerClass = data.modalFor !== 'editRecord' ? 'slds-hide' : 'slds-show';
        this.actionButtonText = data.actionText;
        this.cancelButtonText = data.cancelText;
    }
    @api showModalUploadFile(data){
        this.templateVisible = data.modalFor;
        this.spinnerClass = data.modalFor !== 'editRecord' ? 'slds-hide' : 'slds-show';
        this.actionButtonText = data.actionText;
        this.cancelButtonText = data.cancelText;
        
        this.csvImportData = { hasHeaders : false,hasGridReference : data.hasGridReference,
            modalHeader : data.modalHeader,actionLabel:data.actionText,cancelLabel : data.cancelText};
        this.openModal = true;
    }
    @api showMappingTable(data){
        this.templateVisible = data.modalFor;
        this.spinnerClass = data.modalFor !== 'editRecord' ? 'slds-hide' : 'slds-show';
        this.actionButtonText = data.actionText;
        this.cancelButtonText = data.cancelText;
        
        this.csvImportData = { hasHeaders : data.hasHeaders,file : data.file, recordId : data.recordId,
            modalHeader : data.modalHeader,actionLabel:data.actionText,cancelLabel : data.cancelText,
            previewLabel : data.previewLabel, childObj : data.childObj, picklistValue : data.picklistValue};
        this.openModal = true;
    }
    @api showErrorTable(data){
        this.templateVisible = data.modalFor;
        this.spinnerClass = data.modalFor !== 'editRecord' ? 'slds-hide' : 'slds-show';
        this.cancelButtonText = data.cancelText;
        this.errorTableObj = {columns : (data.columns ? JSON.parse(JSON.stringify(data.columns)) : []),rowData : (data.rowData ? JSON.parse(JSON.stringify(data.rowData)) : []), message : (data.message ? data.message : '')};
        this.openModal = true;
    }
    get hasSelectedTemplate(){
        return this.hasSelectedRecord ? false : true;
    }
    get cancelText(){
        return xLabelService.commonCancel;
    }
    get saveAndMap(){
        return xLabelService.saveAndMap;
    }
    get selectTemplateHelpURL(){
        return KnowledgeBase.selectTemplateScreenHelp;
    }
    get createTemplateHelpURL(){
        return KnowledgeBase.createTemplateScreenHelp;
    }
    get uploadCsvHelpURL(){
        return KnowledgeBase.uploadCSVFromUHL;
    }
    get exportWarning(){
        return xLabelService.csvExportWarning;
    }
    get exportItems(){
        return xLabelService.csvExportWarningHeading;
    }
    prepareImportTemplates(){
        let localOptions = [];
        this.importTemplates && this.importTemplates.forEach(item => {
            localOptions.push({label : item.name, value : item.id});
        })
        this.importTemplateOptions = localOptions;
    }
    @api
    showWarning(data){
        this.warningModalFromData = data;
        this.templateVisible = data.modalFor;
        this.openModal = true;
    }
    prepareFieldsMap(){
        this.setMcolumns();
        let mappings = []
        this.fields && this.fields.forEach(item => {
            if(this.mColumns.get(item)){
                mappings.push({value:this.mColumns.get(item).apiName, key:item});
            }else{
                mappings.push({value:'', key:item});
            }
        });
        if(this.fieldsMap)
            this.fieldsMap['_default']=mappings;
        if(this.templateVisible === 'mapFields'){
            this.chooseMapping = true;
            this.showMappings = false;
            this.hasMoreThanOneSavedMappings = false;
        }
    }
    get noTemplate(){
        return xLabelService.noTemplate;
    }
    get comboLabel(){
        return xLabelService.existingTemplate;
    }
    get createNewMappingText(){
        return xLabelService.createNewMapping;
    }
    get createMapFields(){
        return xLabelService.createMapFields;
    }
    get chooseExisting(){
        return xLabelService.chooseExisting;
    }
    get createTemplate(){
        return xLabelService.createTemplate;
    }
    get commonClose(){
        return xLabelService.close;
    }
    get selectTemplate(){
        return xLabelService.selectTemplate;
    }
    get orText(){
        return xLabelService.commonOr;
    }
    get uploadFile(){
        this.spinnerClass = 'slds-hide';
        return xLabelService.uploadFile;
    }
    get editRecordText(){
        return xLabelService.editRecord;
    }
    get hasTemplates(){
        return this.importTemplateOptions.length === 0 ? false : true;
    }
    get cancelButtonLabel(){
        return xLabelService.stayOnList;
    }
    get refreshButtonLabel(){
        return xLabelService.discardChanges;
    }
    get warningMessage(){
        return xLabelService.warningMessage;
    }
    get editingItems(){
        return xLabelService.editingItems;
    }
    cancelMethod(event) {
        event.preventDefault();
        this.uploadedFileName = '';
        this.dispatchEvent(new CustomEvent('modalcancelclick', { detail : {
            cancelable: true,
            modalData : this.warningModalFromData           
        }}));
        this.closeModal();
    }
    get fieldMapping(){
        return this.fieldsMap[this.userMapping];
    }
    get reviewError(){
        return xLabelService.reviewError;
    }
    saveMethod(event) {
        if(event.target.label === xLabelService.commonNext){
            this.actionButtonText = xLabelService.commonMap;
            return;
        }
        if(this.templateVisible === 'editRecord'){
            this.doMutation();
        }

        this.uploadedFileName = '';
        this.dispatchEvent(new CustomEvent('modalactionclick', { detail :{
            actionFor : this.templateVisible,
            cancelable: true,
            row : this.row,
            fields: this.fields,
            fieldsMap:this.fieldsMap,
            userMapping : this.userMapping,
            data : this.data,
            undoHistory : this.undoHistory  
        }        
        }));
    }
    doMutation(){
        const inputFields = this.template.querySelectorAll(
            'lightning-input-field'
        );
        this.setMcolumns();
        if (inputFields) {
            inputFields.forEach(field => {
                if(this.row[field.fieldName] != field.value){
                    let isPicklist = this.mColumns.get(field.fieldName).type === 'picklist' || this.mColumns.get(field.fieldName).type === 'multipicklist';
                    this.tempHistory.push(this.prepareHistory(field.fieldName,isPicklist,this.row));
                    this.row['_updated'] = true;
                }
                this.row[field.fieldName] = field.value;
            });
        }
        this.undoHistory.push(this.tempHistory);
    }
    setMcolumns(){
        if(!this.mColumns){
            this.mColumns = this.allColumns.reduce( (map, column) => {
                map.set(column.apiName, column);
                return map;
            }, new Map());
        }
    }
    get acceptedFormats(){
        return ['.csv'];
    }
    uploadFileHandler(evt){
        this.uploadedFileName = evt.detail.files[0].name;
        this.loadFile(evt.detail.files[0]);
    }
    async loadFile(file){
        this.data = [];
        this.fields = [];
        await loadScript(this, PARSER + '/javascript/papaparse.min.js');
        const parser = new CsvParser(Papa);

        Papa.parse(file, {
            quoteChar: '"',
            header: 'true',
            complete: (results) => {
                if(results.data.length > 0){
                    this.fields = Object.keys(results.data[0]).filter(value => { return value !== 'rowKey'});
                    this.data = results.data;
                }
            },
            error: (error) => {
                console.error(error);
            }
        })
    }
    prepareHistory(apiName, isPicklistChange, row){
        let tempObj = {rowKey:row.rowKey,colId:apiName,value:row[apiName]};
        if(this.mColumns.get(apiName).type === 'reference'){
            tempObj['lookupApi'] = row[this.mColumns.get(apiName).typeAttributes.label.lookupApi];
        }
        tempObj['isPicklistChange'] = isPicklistChange; 
        return tempObj;
    }

    handleOnLoad(evt){
        this.spinnerClass = 'slds-hide';
    }
    handleSelectionChange(evt){
        this.setMcolumns();
        this.tempHistory.push(this.prepareHistory(evt.detail.apiName,false,this.row));
        this.row['_updated'] = true;
        this.row[evt.detail.apiName] = evt.detail.value ? evt.detail.value : null;
        if(this.mColumns.get(evt.detail.apiName).type === 'reference'){
            this.row[this.mColumns.get(evt.detail.apiName).typeAttributes.label.lookupApi] = evt.detail.value ? {
                Name: evt.detail.label,
                Id: evt.detail.value
            } : null;
        }
    }
    handleCurrencyChange(evt){
        this.setMcolumns();
        this.tempHistory.push(this.prepareHistory(evt.detail.colId,false,this.row));
        this.row['_updated'] = true;
        this.row[evt.detail.colId] = evt.detail.value ? evt.detail.value : null;
    }
    //mapping stuff
    chooseExistingMapping(){
        if(Object.keys(this.fieldsMap).length > 1){
            this.options = [];
            Object.keys(this.fieldsMap).forEach(item =>{
                this.options.push({label:item,value:item});
            });
            this.hasMoreThanOneSavedMappings = true;
        }else{
            this.actionButtonText = xLabelService.commonMap;
        }
        this.chooseMapping = false;
        this.showMappings = true;
    }
    createNewMapping(){
        let mappings = [];
        this.fields && this.fields.forEach(item => {
            mappings.push({value:'', key:item});
        });
        let key = '_default'+ this.gen.next().value;
        this.fieldsMap[key] = mappings;
        this.userMapping = key;
        this.chooseMapping = false;
        this.actionButtonText = xLabelService.commonMap;
        this.showMappings = true;
    }
    handlePicklistChange(evt){
        this.userMapping = evt.target.value;
    }
    handleMappingChange(evt){
        let mapData = this.fieldsMap[evt.detail.userMapping];
        mapData.forEach(function(value) {
            if(value.key === evt.detail.key){
                value.value = evt.detail.value;
            }
            return value;
        });
        this.fieldsMap[evt.detail.userMapping] = mapData;
    }
    handleCreateTemplate(){
        this.dispatchEvent(new CustomEvent('createtemplate'));
    }
    handleSuccess(evt){
        this.spinnerClass = 'slds-hide';
        this.dispatchEvent(new CustomEvent('saverecord', {detail : {
            recordId : evt.detail.id,
            name : evt.detail.fields.Name.value,
            hasHeaders : evt.detail.fields.AcctSeed__Headers__c.value
        }}));
    }
    handleSaveAndMap(){
        this.spinnerClass = 'slds-show';
    }
    cancelEntry(){
        this.dispatchEvent(new CustomEvent('cancelcreation'));
    }
    handleTemplateChange(evt){
        this.helpText = 'slds-hide';
        this.error = '';
        this.hasSelectedRecord = evt.target.value;
    }
    handleModalAction(evt){
        this.dispatchEvent(new CustomEvent('modalaction', { detail : {
            file : evt.detail.file
        }}));
    }
    handleCancel(){
        const csvImport = this.template.querySelector(`c-csv-import[data-id="csvimport"]`);
        csvImport.closeComp();
        this.closeModal();
    }
    handleSelectTemplateAction(){
        this.spinnerClass = 'slds-show';
        let index = this.importTemplates.map(function(item) { return item.id; }).indexOf(this.hasSelectedRecord);

        if(this.mappingObj){
            let showCompData = {importTemplateId : this.importTemplates[index].id,data : this.mappingObj.data,_data : this.mappingObj._data,
                fieldDefinitions : this.mappingObj.fieldDefinitions};
            const csvImportData = this.template.querySelector(`c-csv-import-data[data-id="import-data"]`);
            csvImportData.showComp(showCompData);
        }else{
            let showCompData = {file : this.file,hasHeaders : this.importTemplates[index].hasHeaders,recordId : this.importTemplates[index].id};
            const csvImportData = this.template.querySelector(`c-csv-import-mapping[data-id="import-mapping"]`);
            csvImportData.getMapping(showCompData);
        }
    }
    handleErrorInSave(evt){
        this.dispatchEvent(new CustomEvent('savingerror', {detail : {
            columns : evt.detail.columns ? evt.detail.columns : null,
            rowData : evt.detail.rowData ? evt.detail.rowData : null,
            message : evt.detail.message ? evt.detail.message : ''
        }}));
    }
    handleMappingTableAction(evt){
        this.dispatchEvent(new CustomEvent('mappingsave', {detail : {
            data : evt.detail.data,
            _data : evt.detail._data,
            fieldDefinitions : evt.detail.fieldDefinitions,
            picklistValue : evt.detail.picklistValue
        }}));
    }
    handleMappingReady(evt){
        if(evt.detail.rowData[0].hasFields === false){
            this.dispatchEvent(new CustomEvent('savingerror', {detail : {
                message : xLabelService.csvNoMapping
            }}));
        }else{
            this.mappingObj = {data : evt.detail.data, _data : evt.detail._data};
            let showCompData = {importTemplateId : evt.detail.recordId,data : this.mappingObj.data,_data : this.mappingObj._data,record : evt.detail.parentRecord};
            const csvImportData = this.template.querySelector(`c-csv-import-data[data-id="import-data"]`);
            csvImportData.showComp(showCompData);
        }
    }
    handleRecordSave(evt){
        this.spinnerClass = 'slds-hide';
        this.dispatchEvent(new CustomEvent('recordsaved'));
    }
    handleRefreshSuccess(){
        this.dispatchEvent(new CustomEvent('refreshsuccess', {detail : {modalData : this.warningModalFromData}}));
    }
}