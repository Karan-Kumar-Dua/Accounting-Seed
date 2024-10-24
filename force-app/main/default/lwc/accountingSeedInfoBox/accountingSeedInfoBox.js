import { LightningElement, api } from 'lwc';

export default class AccountingSeedInfoBox extends LightningElement {
    static renderMode = 'light';

    @api infoText;
    @api iconName;
    @api iconTitle;    
}