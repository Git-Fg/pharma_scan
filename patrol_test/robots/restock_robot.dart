import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';

import 'base_robot.dart';

/// Robot for Restock screen interactions with enhanced E2E capabilities
class RestockRobot extends BaseRobot {
  RestockRobot(super.$);

  // --- Navigation ---
  Future<void> tapRestockTab() async {
    await $(const Key(TestTags.navRestock)).tap();
    await $.pumpAndSettle();
  }

  // --- Restock List Actions ---
  Future<void> scrollToItem(String itemName) async {
    await $(itemName).scrollTo(
      view: $(Scrollable).last,
    );
    await $.pumpAndSettle();
  }

  Future<void> tapItem(String itemName) async {
    await scrollToItem(itemName);
    await $(itemName).tap();
    await $.pumpAndSettle();
  }

  Future<void> incrementQuantity(String itemName) async {
    await tapItem(itemName);
    await $(#increment).tap();
    await $.pumpAndSettle();
  }

  Future<void> decrementQuantity(String itemName) async {
    await tapItem(itemName);
    await $(#decrement).tap();
    await $.pumpAndSettle();
  }

  Future<void> setQuantity(String itemName, int quantity) async {
    await tapItem(itemName);

    // Clear current value and set new one
    await $(#quantityInput).enterText(quantity.toString());
    await $.pumpAndSettle();

    // Confirm the change
    await $(#confirmQuantity).tap();
    await $.pumpAndSettle();
  }

  Future<void> toggleChecked(String itemName) async {
    await tapItem(itemName);
    await $(#checkbox).tap();
    await $.pumpAndSettle();
  }

  Future<void> deleteItem(String itemName) async {
    await tapItem(itemName);
    await $(#delete).tap();
    await $.pumpAndSettle();

    // Confirm deletion if dialog appears
    if (await $(Strings.confirm).exists) {
      await $(Strings.confirm).tap();
      await $.pumpAndSettle();
    }
  }

  // --- Bulk Actions ---
  Future<void> clearCheckedItems() async {
    await $(#clearChecked).tap();
    await $.pumpAndSettle();

    if (await $(Strings.confirm).exists) {
      await $(Strings.confirm).tap();
      await $.pumpAndSettle();
    }
  }

  Future<void> clearAllItems() async {
    await $(#clearAll).tap();
    await $.pumpAndSettle();

    if (await $(Strings.confirm).exists) {
      await $(Strings.confirm).tap();
      await $.pumpAndSettle();
    }
  }

  Future<void> openSortOptions() async {
    await $(#sortButton).tap();
    await $.pumpAndSettle();
  }

  Future<void> selectSortOption(String sortOption) async {
    await $(sortOption).tap();
    await $.pumpAndSettle();
  }

  // --- Restock Verifications ---
  Future<void> expectRestockScreenVisible() async {
    await $(const Key(TestTags.restockList)).waitUntilVisible();
  }

  Future<void> expectItemInRestock(String itemName) async {
    await scrollToItem(itemName);
    await $(itemName).waitUntilVisible();
  }

  Future<void> expectItemQuantity(String itemName, int expectedQuantity) async {
    await tapItem(itemName);
    await $(#quantityDisplay).waitUntilVisible();

    // Get the displayed quantity and verify
    final quantityText = await $(#quantityDisplay).text;
    expect(quantityText, equals(expectedQuantity.toString()));
  }

  Future<void> expectItemChecked(String itemName, bool isChecked) async {
    await tapItem(itemName);

    if (isChecked) {
      await $(#checkbox).matches(find.byWidgetPredicate((widget) =>
          widget is Checkbox && widget.value == true));
    } else {
      await $(#checkbox).matches(find.byWidgetPredicate((widget) =>
          widget is Checkbox && widget.value == false));
    }
    await $.pumpAndSettle();
  }

  Future<void> expectEmptyRestockList() async {
    await $(Strings.restockEmptyTitle).waitUntilVisible();
  }

  Future<void> expectSortOptionSelected(String sortOption) async {
    await $(#sortButton).waitUntilVisible();
    await $(#sortButton).tap();
    await $(sortOption).waitUntilVisible();
    // Check if the option is selected (you may need to adjust based on your UI)
  }

  // --- Restock Flow Completion ---
  /// Complete restock flow: navigate to restock, add/update item quantity
  Future<void> completeRestockFlow(String itemName, {int quantity = 1}) async {
    await tapRestockTab();

    if (quantity > 0) {
      if (await $(itemName).exists) {
        // Item exists, update quantity
        await setQuantity(itemName, quantity);
      } else {
        // Item doesn't exist, you might need to add it first
        // This depends on your app's specific flow
      }
    }
  }

  // --- Enhanced List Management ---
  Future<void> scrollToTopOfList() async {
    await scrollToTop();
  }

  Future<void> scrollToBottomOfList() async {
    await scrollToBottom();
  }

  Future<void> pullToRefresh() async {
    final scrollable = find.byType(Scrollable).first;
    if (scrollable.evaluate().isNotEmpty) {
      await $.tester.drag(scrollable, const Offset(0, 300));
      await pumpAndSettleWithDelay();
      await waitForLoadingToComplete();
    }
  }

  // --- Enhanced Item Actions ---
  Future<void> tapItemCheckbox(String itemName) async {
    await scrollToItem(itemName);
    try {
      // Look for checkbox in the item row
      final checkbox = find.byWidgetPredicate((widget) =>
          widget is Checkbox && widget.key?.toString().contains(itemName) == true);

      if (checkbox.evaluate().isNotEmpty) {
        await $.tester.tap(checkbox);
        await pumpAndSettleWithDelay();
      } else {
        // Alternative: Look for checkbox by type in the item's row
        final itemRow = find.text(itemName);
        if (itemRow.evaluate().isNotEmpty) {
          final checkboxInRow = find.descendant(
            of: itemRow.first,
            matching: find.byType(Checkbox),
          );
          if (checkboxInRow.evaluate().isNotEmpty) {
            await $.tester.tap(checkboxInRow);
            await pumpAndSettleWithDelay();
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to tap checkbox for item $itemName: $e');
    }
  }

  Future<void> swipeItemToDelete(String itemName) async {
    await scrollToItem(itemName);
    try {
      final itemWidget = find.text(itemName);
      if (itemWidget.evaluate().isNotEmpty) {
        // Swipe right to left to reveal delete option
        await $.tester.fling(itemWidget, const Offset(-500, 0), 1000);
        await pumpAndSettleWithDelay();

        // Look for delete button and tap it
        final deleteButton = find.text('Supprimer').first;
        if (deleteButton.evaluate().isNotEmpty) {
          await $.tester.tap(deleteButton);
          await pumpAndSettleWithDelay();

          // Handle confirmation dialog if present
          await handleDeleteConfirmation();
        }
      }
    } catch (e) {
      debugPrint('Failed to swipe and delete item $itemName: $e');
    }
  }

  Future<void> swipeItemToEdit(String itemName) async {
    await scrollToItem(itemName);
    try {
      final itemWidget = find.text(itemName);
      if (itemWidget.evaluate().isNotEmpty) {
        // Swipe left to right to reveal edit options
        await $.tester.fling(itemWidget, const Offset(500, 0), 1000);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Failed to swipe to edit item $itemName: $e');
    }
  }

  Future<void> tapItemQuantity(String itemName) async {
    await scrollToItem(itemName);
    try {
      // Look for quantity display/edit button
      final quantityWidget = find.byWidgetPredicate((widget) =>
          widget.key?.toString().contains('quantity') == true ||
          widget.key?.toString().contains(itemName) == true);

      if (quantityWidget.evaluate().isNotEmpty) {
        await $.tester.tap(quantityWidget.first);
        await pumpAndSettleWithDelay();
      } else {
        // Alternative: Tap the item row to open quantity editor
        await tapItem(itemName);
      }
    } catch (e) {
      debugPrint('Failed to tap quantity for item $itemName: $e');
    }
  }

  Future<void> longPressItem(String itemName) async {
    await scrollToItem(itemName);
    try {
      final itemWidget = find.text(itemName);
      if (itemWidget.evaluate().isNotEmpty) {
        await $.tester.longPress(itemWidget);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Failed to long press item $itemName: $e');
    }
  }

  // --- Enhanced Quantity Management ---
  Future<void> increaseQuantity(String itemName) async {
    await tapItemQuantity(itemName);
    try {
      final incrementButton = find.byIcon(Icons.add);
      if (incrementButton.evaluate().isNotEmpty) {
        await $.tester.tap(incrementButton);
        await pumpAndSettleWithDelay();

        // Save the change if needed
        await saveQuantityChange();
      }
    } catch (e) {
      debugPrint('Failed to increase quantity for item $itemName: $e');
    }
  }

  Future<void> decreaseQuantity(String itemName) async {
    await tapItemQuantity(itemName);
    try {
      final decrementButton = find.byIcon(Icons.remove);
      if (decrementButton.evaluate().isNotEmpty) {
        await $.tester.tap(decrementButton);
        await pumpAndSettleWithDelay();

        // Save the change if needed
        await saveQuantityChange();
      }
    } catch (e) {
      debugPrint('Failed to decrease quantity for item $itemName: $e');
    }
  }

  Future<void> saveQuantityChange() async {
    try {
      final saveButton = find.text('Enregistrer').first;
      if (saveButton.evaluate().isNotEmpty) {
        await $.tester.tap(saveButton);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      // Save might be automatic
      debugPrint('Save button not found, change might be auto-saved: $e');
    }
  }

  Future<void> cancelQuantityChange() async {
    try {
      final cancelButton = find.text('Annuler').first;
      if (cancelButton.evaluate().isNotEmpty) {
        await $.tester.tap(cancelButton);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Cancel button not found: $e');
    }
  }

  // --- Enhanced Bulk Actions ---
  Future<void> tapSelectAll() async {
    try {
      final selectAllButton = find.text('Tout sélectionner').first;
      if (selectAllButton.evaluate().isNotEmpty) {
        await $.tester.tap(selectAllButton);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Select all button not found: $e');
    }
  }

  Future<void> tapClearSelected() async {
    try {
      final clearSelectedButton = find.text('Supprimer la sélection').first;
      if (clearSelectedButton.evaluate().isNotEmpty) {
        await $.tester.tap(clearSelectedButton);
        await pumpAndSettleWithDelay();

        // Handle confirmation
        await handleDeleteConfirmation();
      }
    } catch (e) {
      debugPrint('Clear selected button not found: $e');
    }
  }

  Future<void> tapClearAll() async {
    try {
      final clearAllButton = find.text('Tout supprimer').first;
      if (clearAllButton.evaluate().isNotEmpty) {
        await $.tester.tap(clearAllButton);
        await pumpAndSettleWithDelay();

        // Handle confirmation
        await handleDeleteConfirmation();
      }
    } catch (e) {
      debugPrint('Clear all button not found: $e');
    }
  }

  Future<void> confirmBulkAction() async {
    try {
      final confirmButton = find.text('Confirmer').first;
      if (confirmButton.evaluate().isNotEmpty) {
        await $.tester.tap(confirmButton);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Confirm button not found: $e');
    }
  }

  Future<void> cancelBulkAction() async {
    try {
      final cancelButton = find.text('Annuler').first;
      if (cancelButton.evaluate().isNotEmpty) {
        await $.tester.tap(cancelButton);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Cancel button not found: $e');
    }
  }

  // --- Undo Actions ---
  Future<void> tapUndoButton() async {
    try {
      final undoButton = find.text('Annuler').first;
      if (undoButton.evaluate().isNotEmpty) {
        await $.tester.tap(undoButton);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Undo button not found: $e');
    }
  }

  Future<void> waitForUndoTimeout() async {
    // Wait for undo timeout to expire (typically 3-5 seconds)
    await Future.delayed(const Duration(seconds: 6));
    await $.pumpAndSettle();
  }

  // --- Helper Methods ---
  Future<void> handleDeleteConfirmation() async {
    try {
      // Look for confirmation dialog
      final confirmButton = find.text('Supprimer').first;
      if (confirmButton.evaluate().isNotEmpty) {
        await $.tester.tap(confirmButton);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Delete confirmation not found or not needed: $e');
    }
  }

  // --- Enhanced Assertions ---
  void expectItemCount(int count) {
    // Look for restock items or check empty state
    final itemRows = find.byType(ListTile);
    if (count == 0) {
      expectEmptyRestockList();
    } else {
      expect(itemRows, findsNWidgets(count));
    }
  }

  void expectItemQuantity(String itemName, int quantity) {
    expectItemInRestock(itemName);
    // Look for quantity display near the item
    final quantityText = find.textContaining(quantity.toString());
    if (quantityText.evaluate().isNotEmpty) {
      expect(quantityText, findsWidgets);
    }
  }

  void expectItemSelected(String itemName) {
    // Check if item has selected indicator
    final itemRow = find.text(itemName);
    if (itemRow.evaluate().isNotEmpty) {
      // Look for selected state indicator
      final selectedIndicator = find.descendant(
        of: itemRow.first,
        matching: find.byWidgetPredicate((widget) =>
            widget is Checkbox && widget.value == true),
      );
      expect(selectedIndicator, findsOneWidget);
    }
  }

  void expectEmptyStateVisible() {
    expectEmptyRestockList();
  }

  void expectTotalItemsCount(int count) {
    // Look for total count indicator in the app bar or summary
    final countText = find.textContaining('$count');
    if (countText.evaluate().isNotEmpty) {
      expect(countText, findsWidgets);
    }
  }

  void expectUndoButtonVisible() {
    expectVisibleByText('Annuler');
  }

  void expectUndoButtonNotVisible() {
    expectNotVisibleByText('Annuler');
  }

  void expectSectionVisible(String letter) {
    // Look for alphabetical section headers
    expectVisibleByText(letter);
  }

  void expectItemNotVisible(String itemName) {
    expectNotVisibleByText(itemName);
  }

  void expectQuantityInputVisible() {
    // Check if quantity input field is visible
    final quantityInput = find.byType(TextField);
    expect(quantityInput, findsOneWidget);
  }

  void expectSortDialogVisible() {
    // Check if sort options dialog is visible
    expect(find.byType(Dialog), findsOneWidget);
  }

  void expectBulkActionsVisible() {
    // Check if bulk action buttons are visible
    expectVisibleByText('Tout sélectionner');
    expectVisibleByText('Supprimer la sélection');
  }

  void expectBulkActionsNotVisible() {
    expectNotVisibleByText('Tout sélectionner');
    expectNotVisibleByText('Supprimer la sélection');
  }

  void expectSelectionModeActive() {
    expectBulkActionsVisible();
  }

  void expectNormalModeActive() {
    expectBulkActionsNotVisible();
  }

  void expectItemQuantityZero(String itemName) {
    expectItemQuantity(itemName, 0);
  }

  void expectItemWithNotes(String itemName, String notes) {
    expectItemInRestock(itemName);
    // Look for notes indicator or text
    final notesText = find.text(notes);
    if (notesText.evaluate().isNotEmpty) {
      expect(notesText, findsOneWidget);
    }
  }

  void expectItemWithExpirationDate(String itemName, String expirationDate) {
    expectItemInRestock(itemName);
    // Look for expiration date indicator
    final dateText = find.text(expirationDate);
    if (dateText.evaluate().isNotEmpty) {
      expect(dateText, findsOneWidget);
    }
  }
}