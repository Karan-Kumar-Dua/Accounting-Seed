import { LightningElement,api,track,wire } from 'lwc';
import CsvParser from 'c/csvParser';
import {xLabelService} from 'c/xUtils';
import { KnowledgeBase } from 'c/utils';
import { loadScript } from 'lightning/platformResourceLoader';
import PARSER from '@salesforce/resourceUrl/accounting_resources';
import getImportFields from '@salesforce/apex/CSVImportTemplateHelper.getImportFields';
import getImportFieldsDefinition from '@salesforce/apex/CSVImportTemplateHelper.getImportFieldDefinitions';
import importFields from '@salesforce/apex/CSVImportTemplateHelper.importFields';
import getImportTemplate from '@salesforce/apex/CSVImportTemplateHelper.getImportTemplate';
import { LabelService } from 'c/utils';

export default class CsvImportMapping extends LightningElement {
    labels = LabelService;
    showMapping = false;
    actionLabel;
    cancelLabel;
    hasHeaders;
    previewLabel;
    modalHeader;
    picklistValue;
    childObj;
    @track importRecordId;
    helpText = 'slds-hide';
    record;
    error = '';
    @track rowData;
    @track fieldDefinitions;
    @track _data;
    @track spinnerClass = 'slds-hide';
    @track backButtonPressed = false;
    columns = [{ label: xLabelService.header, apiName: "header", type : "header"},
                { label: xLabelService.targetObject, apiName: "targetObject", type : "object"},
                { label: xLabelService.targetField, apiName: "targetField", type: "field"},
                { label: xLabelService.lookupType, apiName: "lookupType", type : "lookupType"},
                { label: xLabelService.lookupField, apiName: "lookupField", type : "lookupField"},
                { label: xLabelService.groupBy, apiName: "groupBy", type : "radio", isRadioButton : true}];
    
    @wire(getImportTemplate, { recordId: '$importRecordId' })
    importTemplate(data, error) {
        if (data) {
            this.record = data;
        }
    }

    get helpURL(){
        return KnowledgeBase.mappingScreenHelp;
    }
    renderedCallback() {
        console.log(this.backButtonPressed);
        if (this.backButtonPressed === true) {
            const previewModal = this.template.querySelector(`c-csv-import-preview[data-id="previewComp"]`);
            previewModal.closeComp();
            this.backButtonPressed = false;
            this.spinnerClass = 'slds-hide';
        }
    }
    @api
    get initialData(){
        return this.hasHeaders;
    }
    set initialData(data){
        if(data){
            this.spinnerClass = 'slds-show';
            this.showMappingHelper(data);
        }
    }

    @api
    showComp(data){
        this.spinnerClass = 'slds-show';
       this.showMappingHelper(data);
    }
    showMappingHelper(data){
        this.importRecordId = data.recordId;
        this.childObj = data.childObj;
        this.picklistValue = data.picklistValue ? data.picklistValue : null;
        this.loadFile(data);
        this.modalHeader = data.modalHeader;
        this.actionLabel = data.actionLabel;
        this.cancelLabel = data.cancelLabel;
        this.previewLabel = data.previewLabel;
        this.showMapping = true;
    }
    @api
    getMapping(data){
        this.importRecordId = data.recordId;
        this.loadFile(data);
    }
    @api
    closeComp(){
        this.showMapping = false;
    }
    @api
    preBuiltData(data){
        this.headers = data.headers;
        this.importRecordId = data.recordId;
        this.rowData = data._data;
        this.data = data.data;
        this._data = data._data;
        this.fieldDefinitions = data.fieldDefinitions;
        this.fetchImportFields();
    }
    @api
    async loadFile(file){
        this.data = [];
        this.headers = [];
        await loadScript(this, PARSER + '/javascript/papaparse.min.js');
        const parser = new CsvParser(Papa);

        Papa.parse(file.file, {
            quoteChar: '"',
            skipEmptyLines: true,
            header: file.hasHeaders,
            complete: (results) => {
                if(results.data.length > 0){
                    this.data = this.getTrimmedData(results.data);  
                    this.headers = Object.keys(this.data[0]);
                    this.fetchImportFields();
                }
            },
            error: (error) => {
                console.error(error);
                this.spinnerClass = 'slds-hide';
            }
        })
    }
    getTrimmedData(tempData){
        let temp = [];
        tempData.map(item =>{
            let obj = {};
            Object.keys(item).forEach(ele =>{
                obj[ele.trim()] = item[ele].trim();
            })
            temp.push(obj);
        });
        return temp;
    }
    fetchImportFields(){
        getImportFields({recordId : this.importRecordId, columns : this.headers, childObj : this.childObj})
            .then((result) => {
                this.rowData = result;
                this.fetchImportFieldsDefinition();
            })  
            .catch((error) =>{
                console.error(error);
                this.spinnerClass = 'slds-hide';
            })
    }
    fetchImportFieldsDefinition(){
        getImportFieldsDefinition({recordId : this.importRecordId})
            .then((result) => {
                this.fieldDefinitions = result;
                if(result.targetObjects.length === 0){
                    this.showErrorModal();
                }else{
                    if(this.fieldDefinitions.error){
                        this.showError({response : [this.fieldDefinitions.error]});
                    }else{
                        this.prepareRowData();
                    }
                }
            })
            .catch((error) => {
                console.error(error);
                this.spinnerClass = 'slds-hide';
            })
    }
    prepareRowData(){
        this._data = this.rowData.map( (row,index) => ({...row,
            rowKey : index
        }));
        this.dispatchEvent(new CustomEvent('ready', { detail : {
            data : this.data,
            _data : this._data,
            recordId : this.importRecordId,
            rowData : this.rowData,
            parentRecord : this.record
        }}));
        this.spinnerClass = 'slds-hide';
    }
    handleSelectionChange(evt){
        let index = this._data.map(function(item) { return item.rowKey; }).indexOf(evt.detail.rowKey);
        if(index !== -1){
            this._data[index][evt.detail.apiName] = evt.detail.value;

            // if target field is deselected. i.e. set to None
            if (!this._data[index].targetField || evt.detail.apiName === 'targetField' || evt.detail.apiName === 'targetObject') {
                this._data[index].lookupField = undefined;
                this._data[index].lookupType = undefined;
                this._data[index].groupBy = undefined;
            }
            if(this._data[index].lookupType === 'Id' || this._data[index].lookupType === 'External Id'){
                this._data[index].lookupField = undefined;
            }
        }
    }
    handleGroupByChange(evt){
        let pos = this._data.map(function(item) { return item.rowKey; }).indexOf(evt.detail.rowKey);
        if(pos !== -1){
            this._data[pos][evt.detail.apiName] = evt.detail.value;
        }
        this._data.forEach((val, index) =>{
            if(index !== pos){
                val[evt.detail.apiName] = 'false';
            }
        })
    }
    handlePreviewButton(){
        let actionData = this._data.filter(function(value){return value.targetObject && value.targetField });
        let tempHeaders = [];
        actionData.forEach(item =>{
            tempHeaders.push({label : item.header, apiName : item.header});
        })
        let previewModalData = {modalHeader : xLabelService.csvPreviewMapping,actionLabel : xLabelService.back,data: this.data,headers : tempHeaders};
        this.showMapping = false;        
        const previewModal = this.template.querySelector(`c-csv-import-preview[data-id="previewComp"]`);
        previewModal.showComp(previewModalData);
    }
    handleBack() {
        this.spinnerClass = 'slds-show';
        setTimeout(() => {
            this.showMapping = true;
            this.backButtonPressed = true;
        }, 200);   
    }
    handleCancelButton(){
        this.dispatchEvent(new CustomEvent('cancel'));
    }
    handleActionButton(){
        this.spinnerClass = 'slds-show';
        let actionData = this._data.filter(function(value){return value.targetObject && value.targetField });

        importFields({importFieldsJson : JSON.stringify(actionData)})
            .then((result) => {
                this.spinnerClass = 'slds-hide';

                const actionEvt = new CustomEvent('action', { detail : {
                    data : this.data,
                    _data : this._data,
                    fieldDefinitions : this.fieldDefinitions,
                    response : result,
                    picklistValue : this.picklistValue
                }});
                this.dispatchEvent(actionEvt);
            })  
            .catch((error) =>{
                this.spinnerClass = 'slds-hide';
                this.showError({response : [e.message]});
                console.error(error);
            })
    }
    @api
    showError(data){
        let errorMessage = '';
        this.helpText = 'slds-show';
        data.response.forEach(item => {
            errorMessage = errorMessage + item + '\n';
        });
        this.error = errorMessage;
        this.spinnerClass = 'slds-hide';
    }
    @api 
    hideError(){
        this.helpText = 'slds-hide';
        this.error = '';
    }
    get hasErrors(){
        return this.error === '' ? false : true;
    }
    get hasDataForPreview(){
        if(this._data){
            let actionData = this._data.filter(function(value){return value.targetObject && value.targetField });
            return actionData.length === 0 ? true : false;
        }
        return true;
    }
    showErrorModal(){
        this.showMapping = false;        
        const errorModal = this.template.querySelector(`c-csv-import-error-table[data-id="error-table"]`);
        errorModal.showError(xLabelService.csvNoObjectSelected);
    }
}