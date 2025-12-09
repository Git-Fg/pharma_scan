# Shadcn UI Components Reference

This document lists every component available in the `shadcn_ui` library for Flutter, along with guidelines on when to use them and best practices derived from the official documentation.

-----

## 1. Layout & Containers

* **Scaffold (Tabs):** When using `AutoTabsRouter`, keep the parent shell free of an `appBar`; let each tab screen own its `Scaffold` header/actions to avoid nested AppBars.

### **Card (`ShadCard`)**

* **Description:** A container that groups related content with a built-in header, title, description, content area, and footer.
* **When to use:**
  * Grouping settings, profile details, or dashboard widgets.
  * When you need a distinct surface with a border and shadow to separate content from the background.
* **Example:**

    ```dart
    ShadCard(
      title: Text('Profile'),
      description: Text('Manage your settings'),
      child: ContentWidget(),
      footer: ShadButton(child: Text('Save')),
    )
    ```

### **Sheet (`ShadSheet`)**

* **Description:** A panel that slides out from the edge of the screen (`top`, `bottom`, `left`, `right`).
* **When to use:**
  * **Mobile:** As a replacement for Dialogs to display complex content like "Edit Profile" forms.
  * **Navigation:** For side menus or filters.
* **Usage:** Trigger using `showShadSheet`.

### **Resizable (`ShadResizablePanelGroup`)**

* **Description:** A layout container that allows users to resize panels dynamically using a handle.
* **When to use:**
  * Creating complex, desktop-like layouts (e.g., IDEs, admin dashboards) with adjustable sidebars or content areas.
  * Supports both `horizontal` (default) and `vertical` axes.
* **Tip:** Double-clicking a handle resets the panel to its default size.

### **Separator (`ShadSeparator`)**

* **Description:** A visual divider to separate content semantically.
* **When to use:**
  * Separating items in a list or distinct sections within a card or layout.
  * Available in `horizontal` and `vertical` variants.

-----

## 2. Forms & Inputs

### **Form (`ShadForm`)**

* **Description:** A wrapper widget that provides validation and state management for its children.
* **When to use:**
  * **Always** wrap input fields (`ShadInputFormField`, `ShadSelectFormField`, etc.) in a `ShadForm` when data submission and validation are required.
* **Key Feature:** Allows access to all field values via a `GlobalKey<ShadFormState>`.

### **Input (`ShadInput`)**

* **Description:** A standard text input field.
* **When to use:**
  * Capturing short text like emails or passwords.
  * **Validation:** Use `ShadInputFormField` inside a `ShadForm` for validation logic.

### **Textarea (`ShadTextarea`)**

* **Description:** A multi-line text input.
* **When to use:**
  * Capturing long text like bios, descriptions, or comments.
  * **Validation:** Use `ShadTextareaFormField`.

### **InputOTP (`ShadInputOTP`)**

* **Description:** A segmented input field optimized for One-Time Passwords.
* **When to use:**
  * Two-factor authentication (2FA) or verification flows.
  * Supports copy-paste natively.
  * **Validation:** Use `ShadInputOTPFormField`.

### **Select (`ShadSelect`)**

* **Description:** A dropdown menu for selecting one or more items from a list.
* **When to use:**
  * When users need to pick from a long list of options (e.g., Timezones).
  * **Best Practice:** Use `ShadSelect.withSearch` if the list exceeds 10-15 items to allow filtering.
  * **Validation:** Use `ShadSelectFormField`.

### **Checkbox (`ShadCheckbox`)**

* **Description:** A binary toggle for selection.
* **When to use:**
  * Terms and Conditions acceptance.
  * Selecting multiple items from a list.
  * **Validation:** Use `ShadCheckboxFormField`.

### **RadioGroup (`ShadRadioGroup`)**

* **Description:** A set of exclusive options where only one can be selected.
* **When to use:**
  * When users must choose exactly one option and all options should be visible (unlike a Select dropdown).
  * **Validation:** Use `ShadRadioGroupFormField`.

### **Switch (`ShadSwitch`)**

* **Description:** A toggle switch for binary states.
* **When to use:**
  * Settings like "Airplane Mode" or "Push Notifications".
  * **Validation:** Use `ShadSwitchFormField`.

### **Slider (`ShadSlider`)**

* **Description:** A drag handle for selecting a value within a range.
* **When to use:**
  * Adjusting volume, brightness, or other contiguous numerical values.

### **Date & Time Pickers**

* **Calendar (`ShadCalendar`):** A raw date grid. Use for inline date displays.
* **DatePicker (`ShadDatePicker`):** An input that opens a calendar popover. Supports single dates or ranges. Use `ShadDatePickerFormField` for forms.
* **TimePicker (`ShadTimePicker`):** A clock/input for time. Use `ShadTimePickerFormField` or `ShadTimePickerFormField.period` (AM/PM) for forms.

-----

## 3. Feedback & Overlays

### **Dialog (`ShadDialog`)**

* **Description:** A modal overlay that interrupts the user.
* **When to use:**
  * **Custom Content:** `ShadDialog` for editing profiles or complex interactions inside a modal.
  * **Alerts:** `ShadDialog.alert` for critical confirmations (e.g., "Are you absolutely sure?" before deleting content).

### **Alert (`ShadAlert`)**

* **Description:** A static callout box displayed inline with content.
* **When to use:**
  * Displaying important information ("Heads up!") or errors ("Session expired") directly on the screen.
  * **Do not use** for popups (use Dialog or Toast instead).
  * **Variants:** Standard and `destructive`.

### **Toast (`ShadToast`) / Sonner (`ShadSonner`)**

* **Description:** Temporary non-modal notifications.
* **When to use:**
  * **Standard Toast:** Simple feedback like "Message sent". Trigger via `ShadToaster.of(context).show()`.
  * **Sonner:** An opinionated, advanced toast (stacking, swipe to dismiss). Use `ShadSonner.of(context)`. Good for undo actions or success states.

### **Popover (`ShadPopover`)**

* **Description:** A small content overlay triggered by a button.
* **When to use:**
  * Settings panels for specific elements (e.g., dimensions configuration) that don't require a full dialog.

### **Tooltip (`ShadTooltip`)**

* **Description:** Informational text that appears on hover or focus.
* **When to use:**
  * Explaining icon-only buttons or complex UI elements.
* **Caveat:** Hover only works if the child implements `ShadGestureDetector` (like `ShadButton`). If wrapping a standard widget (e.g., `Image`), you must wrap it in `ShadGestureDetector` manually.

### **Progress (`ShadProgress`)**

* **Description:** A bar showing task completion.
* **When to use:**
  * **Determinate:** When percentage is known (e.g., `value: 0.5`).
  * **Indeterminate:** When loading state is unknown.

-----

## 4. Navigation & Menus

### **Button (`ShadButton`)**

* **Description:** The primary interactive element.
* **When to use:**
  * Triggering actions.
  * **Variants:** `Primary`, `Secondary`, `Destructive` (danger), `Outline` (low priority), `Ghost` (minimal), `Link`.
  * **Features:** Supports loading states, icons (`leading`/`trailing`), and gradients.

### **IconButton (`ShadIconButton`)**

* **Description:** A button that contains only an icon.
* **When to use:**
  * Space-constrained actions (e.g., toolbar actions).
  * Supports the same variants as `ShadButton`.

### **Tabs (`ShadTabs`)**

* **Description:** Segmented controls to switch between views within the same context.
* **When to use:**
  * Switching between "Account" and "Password" settings without leaving the page.

### **Menubar (`ShadMenubar`)**

* **Description:** A persistent top-level menu bar (e.g., File, Edit, View).
* **When to use:**
  * Desktop applications or complex web apps requiring familiar desktop navigation patterns.

### **Context Menu (`ShadContextMenuRegion`)**

* **Description:** A menu triggered by a right-click.
* **When to use:**
  * Providing secondary actions (Back, Reload, Save As) specific to a region of the UI.

-----

## 5. Data Display

### **Table (`ShadTable`)**

* **Description:** A responsive grid for displaying data.
* **When to use:**
  * **`ShadTable.list`:** For **small** datasets. Renders all children at once.
  * **`ShadTable` (Builder):** For **large** datasets. Renders rows on demand for performance.

### **Accordion (`ShadAccordion`)**

* **Description:** Stacked headings that expand/collapse content.
* **When to use:**
  * FAQs or organizing complex details into collapsible sections.
  * Supports `single` or `multiple` items open at once.

### **Avatar (`ShadAvatar`)**

* **Description:** User profile image.
* **When to use:**
  * Representing users. Includes built-in support for fallback text (e.g., initials "CN") if the image fails to load.

### **Badge (`ShadBadge`)**

* **Description:** Small status indicators.
* **When to use:**
  * Labeling items (e.g., "Primary", "Outline").
  * Tags or status flags.

-----

## 6. Utilities

### **Theme (`ShadThemeData`)**

* **Usage:** Customize the entire app's look. Supports 12 built-in color schemes (e.g., `zinc`, `slate`, `blue`).
* **Customization:** You can extend color schemes with custom values.

### **Typography (`ShadTextTheme`)**

* **Usage:** Access predefined text styles via `ShadTheme.of(context).textTheme`.
* **Styles:** `h1Large`, `h1`-`h4`, `p`, `lead`, `large`, `small`, `muted`, `blockquote`, `code`, `list`.

### **Responsive (`ShadResponsiveBuilder`)**

* **Usage:** Build layouts based on screen size breakpoints (`tn`, `sm`, `md`, `lg`, `xl`, `xxl`).
* **Example:**

    ```dart
    ShadResponsiveBuilder(
      builder: (context, breakpoint) => breakpoint >= ShadTheme.of(context).breakpoints.sm
          ? DesktopWidget()
          : MobileWidget(),
    )
    ```

## Patterns UX

### Gestion des suppressions avec Undo

* Suppression optimiste + toast avec bouton "Annuler" (outline, size `sm`) visible ~4s.
* Éviter les dialogues modaux pour les suppressions unitaires.

### Code couleur galénique

* Bordure gauche colorée pour signaler la forme :
  * 🔵 Solides (Comprimés/Gélules/Capsules)
  * 🟠 Liquides (Sirops/Solutions/Buvables)
  * 🟣 Semi-solides (Crèmes/Gels/Pommades)
  * 🔴 Injectables

### États vides actionnables

* Toujours proposer un CTA principal (ex : "Ouvrir le Scanner") pour sortir de l'état vide.
* Ajouter icône, titre et sous-texte concis pour cadrer l'action attendue.
