import {LightningElement, api} from 'lwc';

export default class XDataTableButtons extends LightningElement {
    @api actions;
    handleActionClick(evt){
        const select = new CustomEvent('actionclick', {
            detail: {
                actionName: evt.target.dataset.actionName,
                actionGlobal : evt.target.dataset.actionGlobal
            }
        });
        this.dispatchEvent(select);
    }
}