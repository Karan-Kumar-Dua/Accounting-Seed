import { LightningElement,api,track,wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import {showToastMessage,xLabelService} from 'c/xUtils';
import { KnowledgeBase, LabelService } from 'c/utils';
import getImportTemplate from '@salesforce/apex/CSVImportTemplateHelper.getImportTemplate';


export default class CsvImportTemplateSetup extends LightningElement {
    @api recordId;
    @track csvImportData;
    @track record;
    @track spinnerClass = 'slds-hide';
    labels = LabelService;

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
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    handleModalAction(evt){
        //this.spinnerClass = 'slds-show';
        const csvImportData = this.template.querySelector(`c-csv-import[data-id="csvimport"]`);
        csvImportData.closeComp();

        let mappingData = {actionLabel :xLabelService.commonImport,cancelLabel :xLabelService.commonCancel,modalHeader : xLabelService.importFields,
            file : evt.detail.file, recordId : this.recordId, hasHeaders : this.record.data ? this.record.data.hasHeaders : true,
            previewLabel : xLabelService.preview, childObj : this.record.data.detail};
        const csvImportMapping = this.template.querySelector(`c-csv-import-mapping[data-id="mapping"]`);
        csvImportMapping.closeComp();
        csvImportMapping.showComp(mappingData);
    }
    handleAction(evt){
        if(evt.detail.response.length === 0){
            showToastMessage(this, xLabelService.commonSuccess, xLabelService.dataSavedSuccessfully, 'success');
            this.handleCancel();
        }else{
            const csvImportMapping = this.template.querySelector(`c-csv-import-mapping[data-id="mapping"]`);
            csvImportMapping.showError(evt.detail);
        }
    }
    handleReady(evt){
        this.spinnerClass = 'slds-hide';
    }

    get helpLink() {
        return KnowledgeBase.importCSVSetupScreenHelp;
    }
}