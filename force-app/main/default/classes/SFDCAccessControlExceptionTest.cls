@isTest
private class SFDCAccessControlExceptionTest {
    static testMethod void SFDCAccessControlExceptionTest() {
        String eText = 'Access Violation';
        SFDCAccessControlException.ExceptionType eType = SFDCAccessControlException.ExceptionType.GENERIC;
        SFDCAccessControlException.ExceptionReason eReason = SFDCAccessControlException.ExceptionReason.NO_UPDATE;
        String eObject = Contact.sObjectType.getDescribe().getName();
        String eField = 'test';

        SFDCAccessControlException ex = new SFDCAccessControlException(eText, eType, eReason, eObject, eField);

        System.assertEquals(ex.ExceptionMessage, eText + ' : ' + eType + ' - ' + eReason + ' : ' + eObject + '.' + eField);

        System.assertEquals(ex.getText(), eText);
        System.assertEquals(ex.getExceptionField(), eField);
        System.assertEquals(ex.getExceptionObject(), eObject);
        System.assertEquals(ex.getExceptionType(), eType);
        System.assertEquals(ex.getExceptionReason(), eReason);
    }

}