import { LightningElement,api,track,wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import {showToastMessage,xLabelService} from 'c/xUtils';
import getImportTemplate from '@salesforce/apex/CSVImportTemplateHelper.getImportTemplate';
import { LabelService } from 'c/utils';


export default class CsvImportAction extends LightningElement {
    labels = LabelService;
    @api recordId;
    @track csvImportData;
    @track record;
    @track spinnerClass = 'slds-hide';

    @wire(getImportTemplate, { recordId: '$recordId' })
    importTemplate(data, error) {
        if (data) {
            this.record = data;
        }
    }
    connectedCallback(){
        this.csvImportData = { hasHeaders : false,hasGridReference : false,
            modalHeader :  xLabelService.csvUploadYourFile,actionLabel: xLabelService.commonNext,cancelLabel : xLabelService.commonCancel};
    }
    handleCancel(){
        this.spinnerClass = 'slds-hide';
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    handleModalAction(evt){
        this.spinnerClass = 'slds-show';
        let mappingData = {file : evt.detail.file, recordId : this.recordId, hasHeaders : this.record.data ? this.record.data.hasHeaders : true};
        const csvImportMapping = this.template.querySelector(`c-csv-import-mapping[data-id="mapping"]`);
        csvImportMapping.getMapping(mappingData);
    }
    handleReady(evt){
        if(evt.detail.rowData[0].hasFields === false){
            this.spinnerClass = 'slds-hide';
            const csvImport = this.template.querySelector(`c-csv-import[data-id="csvimport"]`);
            csvImport.closeComp();

            const csvError = this.template.querySelector(`c-csv-import-error-table[data-id="error-table"]`);
            csvError.showError(xLabelService.csvNoMapping);
        }else{
            let showCompData = {importTemplateId : this.recordId,data : evt.detail.data,_data : evt.detail._data,record : evt.detail.parentRecord};
            const csvImportCompData = this.template.querySelector(`c-csv-import-data[data-id="import-data"]`);
            csvImportCompData.showComp(showCompData);
        }
    }
    handleRecordSave(){
        this.spinnerClass = 'slds-hide';
        showToastMessage(this, xLabelService.commonSuccess, xLabelService.csvImportSuccess, 'success');
        this.handleCancel();
    }
    handleErrorResponse(evt){
        const csvImport = this.template.querySelector(`c-csv-import[data-id="csvimport"]`);
        csvImport.closeComp();
        
        let data = {columns : evt.detail.columns , rowData : evt.detail.rowData};
        const csvError = this.template.querySelector(`c-csv-import-error-table[data-id="error-table"]`);
        csvError.showComp(data);

        this.spinnerClass = 'slds-hide';
    }   
    handleNoObject(evt){
        const csvImport = this.template.querySelector(`c-csv-import[data-id="csvimport"]`);
        csvImport.closeComp();
        
        const csvError = this.template.querySelector(`c-csv-import-error-table[data-id="error-table"]`);
        csvError.showError(evt.detail.message);
        this.spinnerClass = 'slds-hide';
    }   
}