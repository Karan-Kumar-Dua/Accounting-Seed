@isTest(seeAllData=false)
public with sharing class FilePreviewCarouselFieldOptionsTest {
  @isTest
  static void testTimelinePicklistDefaultValue() {
    VisualEditor.DesignTimePageContext context = new VisualEditor.DesignTimePageContext();
    context.entityName = 'Contact';
    FilePreviewCarouselFieldOptions timeline = new FilePreviewCarouselFieldOptions(context);
    Test.startTest();
    VisualEditor.DataRow defaultValue = timeline.getDefaultValue();
    Test.stopTest();
    Assert.isNotNull(defaultValue);
  }
  @isTest
  static void testTimelinePicklistValues() {
    VisualEditor.DesignTimePageContext context = new VisualEditor.DesignTimePageContext();
    context.entityName = 'Contact';
    FilePreviewCarouselFieldOptions timeline = new FilePreviewCarouselFieldOptions(context);
    Test.startTest();
    VisualEditor.DynamicPickListRows picklistValues = timeline.getValues();
    Test.stopTest();
    Assert.isNotNull(picklistValues);
  }
}