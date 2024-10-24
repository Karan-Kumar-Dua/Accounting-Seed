import { LightningElement, api } from 'lwc';

export default class CardTitleStacked extends LightningElement {
    @api iconName = '';
    @api label = '';
    @api value = '';
}