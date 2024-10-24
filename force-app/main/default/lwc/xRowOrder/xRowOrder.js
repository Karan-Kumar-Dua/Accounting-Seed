import { LightningElement, api, track } from 'lwc';
import { LabelService } from 'c/utils';

export default class XRowOrder extends LightningElement {
    labels = LabelService;
    @api keyField;
    @api column;
    @api row;

    isEditMode = false;
    
    get inEditMode(){
        return this.row['inEditMode'] ? true : this.isEditMode;
    }
    get fieldValue(){
        return this.row[this.column.apiName];
    }
    handleEditClick(evt){
        this.isEditMode = !this.isEditMode;
    }
    get dirtyCell(){
        return (this.row['_row'][this.column.apiName] !== this.row[this.column.apiName]) ? 'cellClass yellowBg' : 'cellClass'; 
    }
    handleOrderFieldBlur(evt){
        if(this.row[this.column.apiName] == evt.target.value){
            this.manageEditMode();
            return;
        }
        const mutation = new CustomEvent('orderchange', {
            detail: {
                rowKey: this.row[this.keyField],
                value: evt.target.value ? evt.target.value : 0
            },
            bubbles : true,
            composed : true
        });
        this.dispatchEvent(mutation);
        this.manageEditMode();
    }
    manageEditMode(){
        this.isEditMode = this.row['inEditMode'] ? true : false;
    }
}