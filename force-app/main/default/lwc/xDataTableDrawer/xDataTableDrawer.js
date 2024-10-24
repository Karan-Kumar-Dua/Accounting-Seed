/**
 * Created by ryansieve on 12/29/21.
 */

import {api, LightningElement,track} from 'lwc';

export default class XDataTableDrawer extends LightningElement {

    @api keyField;
    @api row;
    @api drawer;
    @api initialData;
    @api childReference;
    @api colSpan;
}