import { LightningElement,api } from 'lwc';
import {xLabelService} from 'c/xUtils';
import { KnowledgeBase, LabelService } from 'c/utils';

export default class CsvImportPreview extends LightningElement {
    showPreview = false;
    actionLabel;
    modalHeader;
    data;
    headers;
    spinnerClass = 'slds-hide';
    labels = LabelService;

    @api
    showComp(data){
        this.modalHeader = data.modalHeader;
        this.actionLabel = data.actionLabel;
        this.data = data.data.slice(0,5);
        this.headers = data.headers;
        // this.prepareHeaders(data.headers);
        this.showPreview = true;
    }
    prepareHeaders(){
        let localCols = [];
        Object.keys(this.data[0]).forEach(item =>{
            localCols.push({ label: item.toUpperCase(), apiName: item});
        });
        this.headers = localCols;
    }
    @api
    closeComp(){
        this.showPreview = false;
        this.spinnerClass = 'slds-hide';
    }
    handleActionButton(){
        this.dispatchEvent(new CustomEvent('back'));
    }
    get message(){
        return xLabelService.csvTopRows;
    }
    get helpURL(){
        return KnowledgeBase.previewScreenHelp;
    }
}