import {LightningElement,api } from 'lwc';
import { LabelService } from 'c/utils';

export default class XDataTableRowLevelAction extends LightningElement {
    @api actions;
    @api row;
    labels = LabelService;
    handleMenuClick(evt){
        evt.preventDefault();
        const rowAction = new CustomEvent('rowaction',{
            detail :{
                actionName : evt.target.value,
                row : this.row
            },
            bubbles : true,
            composed : true
        });
        this.dispatchEvent(rowAction);
    }
}