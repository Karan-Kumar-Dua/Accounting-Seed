import { LightningElement,api,track } from 'lwc';
import {xLabelService} from 'c/xUtils';
import { KnowledgeBase } from 'c/utils';

export default class CsvImport extends LightningElement {
    @api kbHelpLink;
    uploadedFileName;
    showUploadFile = false;
    actionLabel;
    cancelLabel;
    hasHeaders;
    modalHeader;
    file;
    error='';
    helpText = 'slds-hide';
    @track data;
    @track headers;

    get helpURL(){
        if (this.kbHelpLink) {
            return this.kbHelpLink
        }
        return KnowledgeBase.importCSVScreenHelp;
    }

    @api 
    get importData(){
        return this.showUploadFile;
    }
    set importData(data){
        if(data){
            this.setDataHelper(data);
        }
    }
    @api
    showComp(data){
        this.setDataHelper(data);
    }
    setDataHelper(data){
        this.hasHeaders = data.hasHeaders;
        this.modalHeader = data.modalHeader;
        this.actionLabel = data.actionLabel;
        this.cancelLabel = data.cancelLabel;
        this.showUploadFile = true;
    }
    @api
    closeComp(){
        this.showUploadFile = false;
    }
    get hasFieldsDefinition(){
        return this.file ? false : true;
    }
    get acceptedFormats(){
        return ['.csv'];
    }
    get supportedFileText() {
        return xLabelService.supportedFile;
    }
    uploadFileHandler(evt){
        this.uploadedFileName = evt.detail.files[0].name;
        let type = evt.detail.files[0].name.toLowerCase();
        if(type.endsWith('.csv')){
            this.error = '';
            this.file = evt.detail.files[0];
        }else{
            this.file = null;
            this.error = xLabelService.onlyCSVCanBeUploaded;
        }
    }
    handleCloseButton(){
        this.dispatchEvent(new CustomEvent('cancel'));
    }   
    handleActionButton(){
        const actionEvt = new CustomEvent('action', {detail : {
            data : this.data,
            headers : this.headers,
            file : this.file
        }});
        this.dispatchEvent(actionEvt);
    }
    @api
    showError(data){
        let errorMessage = '';
        this.helpText = 'slds-show';
        data.response.forEach(item => {
            errorMessage = errorMessage + item + '\n';
        });
        this.error = errorMessage;
    }
    @api 
    hideError(){
        this.helpText = 'slds-hide';
        this.error = '';
    }
}