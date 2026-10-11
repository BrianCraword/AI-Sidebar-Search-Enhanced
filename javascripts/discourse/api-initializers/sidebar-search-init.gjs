/* ============================================================================
   AI SIDEBAR SEARCH ENHANCED
   Live filtering + Delete buttons for AI Conversations sidebar
   v1.0.0 - Complete rewrite with true in-sidebar filtering
   ============================================================================ */

import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";

export default apiInitializer("1.0.0", (api) => {
  const log = (...a) => console.log("[ai-sidebar-search]", ...a);

  // Selectors
  const PANEL_SELECTOR = ".sidebar-sections.ai-conversations-panel";
  const SEARCH_WRAPPER_ID = "vc-sidebar-search";
  const ROW_SELECTOR = ".sidebar-section-link.sidebar-row";
  const HEADER_SELECTOR = ".sidebar-section-header";
  const SECTION_SELECTOR = ".sidebar-section";

  // Check if user is allowed (TL1+ or staff)
  function isAllowedUser() {
    const user = api.getCurrentUser?.();
    if (!user) return false;
    return user.staff || user.trust_level >= 1;
  }

  // Build the search box
  function buildSearchBox() {
    const wrapper = document.createElement("div");
    wrapper.id = SEARCH_WRAPPER_ID;
    wrapper.className = "vc-search-wrapper";
    wrapper.innerHTML = `
      <div class="vc-search-input-group">
        <input 
          type="text" 
          class="vc-search-input" 
          id="vc-sidebar-filter" 
          placeholder="Filter conversations..."
          autocomplete="off"
        />
        <span class="vc-search-icon">🔍</span>
      </div>
    `;
    return wrapper;
  }

  // Inject delete button into each conversation row
  function injectDeleteButtons(panel) {
    const rows = panel.querySelectorAll(ROW_SELECTOR);
    
    rows.forEach(row => {
      // Skip if already has delete button
      if (row.querySelector('.vc-delete-btn')) return;
      
      // Extract topic ID from class name (e.g., ai-conversation-12345)
      const classMatch = row.className.match(/ai-conversation-(\d+)/);
      if (!classMatch) return;
      
      const topicId = classMatch[1];
      
      // Create delete button
      const deleteBtn = document.createElement("button");
      deleteBtn.className = "vc-delete-btn";
      deleteBtn.setAttribute("data-topic-id", topicId);
      deleteBtn.setAttribute("aria-label", "Delete conversation");
      deleteBtn.setAttribute("title", "Delete conversation");
      deleteBtn.textContent = "×";
      
      // Prevent row navigation when clicking delete
      deleteBtn.addEventListener("click", async (e) => {
        e.preventDefault();
        e.stopPropagation();
        
        if (!confirm("Delete this conversation? This cannot be undone.")) {
          return;
        }
        
        try {
          // Use Discourse's ajax helper - handles CSRF automatically
          await ajax(`/t/${topicId}.json`, {
            type: "DELETE"
          });
          
          // Animate removal
          row.style.transition = "opacity 0.3s, transform 0.3s";
          row.style.opacity = "0";
          row.style.transform = "translateX(-20px)";
          
          setTimeout(() => {
            row.remove();
            updateHeaderVisibility(panel);
            log("Deleted conversation:", topicId);
          }, 300);
        } catch (err) {
          console.error("[ai-sidebar-search] Delete error:", err);
          alert("Failed to delete conversation. You may not have permission.");
        }
      });
      
      row.appendChild(deleteBtn);
    });
  }

  // Update header visibility based on visible rows
  // Works with flat DOM structure where headers and items are siblings
  function updateHeaderVisibility(panel) {
    // First, try the section-based approach
    const sections = panel.querySelectorAll(SECTION_SELECTOR);
    
    if (sections.length > 0) {
      sections.forEach(section => {
        const header = section.querySelector(HEADER_SELECTOR);
        const allRows = section.querySelectorAll(ROW_SELECTOR);
        const visibleRows = section.querySelectorAll(`${ROW_SELECTOR}:not(.vc-hidden)`);
        
        if (header && allRows.length > 0) {
          header.classList.toggle("vc-hidden", visibleRows.length === 0);
        }
      });
    } else {
      // Fallback: flat structure - headers and items are siblings
      const headers = panel.querySelectorAll(HEADER_SELECTOR);
      
      headers.forEach((header, idx) => {
        const nextHeader = headers[idx + 1];
        let hasVisibleItem = false;
        let sibling = header.nextElementSibling;
        
        // Check all siblings until the next header (or end)
        while (sibling && sibling !== nextHeader) {
          if (sibling.matches && sibling.matches(ROW_SELECTOR)) {
            if (!sibling.classList.contains("vc-hidden")) {
              hasVisibleItem = true;
              break;
            }
          }
          // Also check inside list items
          const row = sibling.querySelector?.(ROW_SELECTOR);
          if (row && !row.classList.contains("vc-hidden")) {
            hasVisibleItem = true;
            break;
          }
          sibling = sibling.nextElementSibling;
        }
        
        header.classList.toggle("vc-hidden", !hasVisibleItem);
        
        // Also hide the header's parent wrapper if it exists
        const wrapper = header.closest(".sidebar-section-header-wrapper");
        if (wrapper) {
          wrapper.classList.toggle("vc-hidden", !hasVisibleItem);
        }
      });
    }
  }

  // Live filter function
  function filterConversations(panel, query) {
    const rows = panel.querySelectorAll(ROW_SELECTOR);
    const normalizedQuery = query.toLowerCase().trim();
    
    rows.forEach(row => {
      const title = row.textContent.toLowerCase();
      const matches = normalizedQuery === "" || title.includes(normalizedQuery);
      row.classList.toggle("vc-hidden", !matches);
    });
    
    updateHeaderVisibility(panel);
  }

  // Initialize the enhanced search
  function initEnhancedSearch() {
    const panel = document.querySelector(PANEL_SELECTOR);
    if (!panel) return;
    
    // Only for allowed users
    if (!isAllowedUser()) return;
    
    // Don't duplicate
    if (document.getElementById(SEARCH_WRAPPER_ID)) return;
    
    // Build and inject search box
    const searchBox = buildSearchBox();
    panel.insertBefore(searchBox, panel.firstChild);
    
    // Set up live filtering
    const input = document.getElementById("vc-sidebar-filter");
    if (input) {
      input.addEventListener("input", (e) => {
        filterConversations(panel, e.target.value);
      });
      
      // Clear filter on Escape
      input.addEventListener("keydown", (e) => {
        if (e.key === "Escape") {
          input.value = "";
          filterConversations(panel, "");
          input.blur();
        }
      });
    }
    
    // Inject delete buttons
    injectDeleteButtons(panel);
    
    log("Enhanced search initialized");
  }

  // Build left sidebar toggle button (matching right sidebar style exactly)
  function buildLeftToggleButton() {
    const btn = document.createElement("button");
    btn.id = "vc-left-sidebar-toggle";
    btn.setAttribute("aria-label", "Toggle conversation history");
    btn.setAttribute("title", "Open conversations");
    btn.innerHTML = `<span class="vc-chevron-left">‹</span>`;
    return btn;
  }

  // Initialize left sidebar toggle for mobile
  function initLeftSidebarToggle() {
    // Only on AI conversations page
    if (!document.body.classList.contains('ai-bot-conversations-page')) {
      // Remove toggle if it exists but we're not on AI page
      const existing = document.getElementById("vc-left-sidebar-toggle");
      if (existing) existing.remove();
      return;
    }

    // Only show on MAIN listing page, not inside individual chats
    // Main listing: /discourse-ai/ai-bot/conversations
    // Individual chat: /discourse-ai/ai-bot/conversations/123
    const path = window.location.pathname;
    const isMainListingPage = path === '/discourse-ai/ai-bot/conversations' || 
                               path === '/discourse-ai/ai-bot/conversations/';
    
    if (!isMainListingPage) {
      // Remove toggle if navigated to a specific chat
      const existing = document.getElementById("vc-left-sidebar-toggle");
      if (existing) existing.remove();
      log("Not on main listing page, toggle removed");
      return;
    }

    // Don't duplicate
    if (document.getElementById("vc-left-sidebar-toggle")) {
      return;
    }

    const toggleBtn = buildLeftToggleButton();
    document.body.appendChild(toggleBtn);

    // Toggle functionality - click Discourse's hamburger menu
    toggleBtn.addEventListener("click", () => {
      // Find and click Discourse's hamburger menu button
      const hamburger = document.getElementById("toggle-hamburger-menu") || 
                        document.querySelector(".hamburger-dropdown button") ||
                        document.querySelector("[data-toggle='hamburger-menu']");
      
      if (hamburger) {
        hamburger.click();
        log("Clicked hamburger menu");
      } else {
        // Fallback: try to toggle our own class
        document.body.classList.toggle("vc-left-sidebar-open");
        const isOpen = document.body.classList.contains("vc-left-sidebar-open");
        toggleBtn.setAttribute("title", isOpen ? "Close conversations" : "Open conversations");
        toggleBtn.setAttribute("aria-expanded", isOpen);
        log("Toggled sidebar class (fallback)");
      }
    });

    log("Left sidebar toggle initialized on main listing page");
  }

  // Re-inject delete buttons when sidebar updates
  function refreshDeleteButtons() {
    const panel = document.querySelector(PANEL_SELECTOR);
    if (panel && isAllowedUser()) {
      injectDeleteButtons(panel);
    }
  }

  // Full initialization - includes panel-dependent and independent parts
  function fullInit() {
    // Always try to init the left toggle (doesn't need panel)
    initLeftSidebarToggle();
    
    // Try to init search (needs panel)
    initEnhancedSearch();
  }

  // Initial execution
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", fullInit);
  } else {
    fullInit();
  }

  // SPA navigation
  api.onPageChange(() => {
    setTimeout(fullInit, 100);
  });

  // Watch for the panel to appear (mobile hamburger menu)
  // This catches when the panel is dynamically added to the DOM
  const documentObserver = new MutationObserver((mutations) => {
    // Check if we're on the right page
    if (!document.body.classList.contains('ai-bot-conversations-page')) {
      return;
    }
    
    // Look for our panel in mutations
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType !== Node.ELEMENT_NODE) continue;
        
        // Check if the added node is or contains our panel
        const panel = node.matches?.(PANEL_SELECTOR) 
          ? node 
          : node.querySelector?.(PANEL_SELECTOR);
          
        if (panel && !document.getElementById(SEARCH_WRAPPER_ID)) {
          log("Panel appeared in DOM, injecting search");
          initEnhancedSearch();
          return;
        }
      }
    }
  });

  // Start observing the document for panel appearance
  documentObserver.observe(document.body, { 
    childList: true, 
    subtree: true 
  });

  // Also watch for conversations being added to existing panel
  const panelObserver = new MutationObserver(() => {
    refreshDeleteButtons();
  });
  
  // Try to observe panel if it exists
  const existingPanel = document.querySelector(PANEL_SELECTOR);
  if (existingPanel) {
    panelObserver.observe(existingPanel, { childList: true, subtree: true });
  }

});

