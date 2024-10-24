import { LightningElement,track,api } from 'lwc';
import {xLabelService} from 'c/xUtils';
import { KnowledgeBase } from 'c/utils';


export default class CsvImportErrorTable extends LightningElement {
    @api columns;
    @api rowData;
    @api message = '';
    @api showTable = false;

    get helpURL(){
        return KnowledgeBase.reviewErrorScreenHelp;
    }
    @api 
    showComp(data){
        this.columns = data.columns;
        this.rowData = data.rowData;
        this.showTable = true;
    }
    @api 
    showError(message){
        this.message = message;
        this.showTable = true;
    }
    @api
    get showErrorTable(){
        return undefined;
    }
    set showErrorTable(val){
        this.columns = val.columns ? val.columns : [];
        this.rowData = val.rowData ? val.rowData : [];
        this.message = val.message ? val.message : '';
        this.showTable = true;

    }
    @api 
    closeComp(){
        this.showTable = false;
    }
    get cancelLabel(){
        return xLabelService.commonCancel;
    }
    get modalHeader(){
        return xLabelService.reviewError;
    }    
    get hasErrorMessage(){
        return this.message === '' ? false : true;
    }
}