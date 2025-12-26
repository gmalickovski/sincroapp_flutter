// Navigation state
let currentFeatureIndex = 0;
let totalFeatures = 0;

// Navigate to specific feature
function navigateToFeature(index) {
    const blocks = document.querySelectorAll('.feature-block');
    if (!blocks || blocks.length === 0) return;

    totalFeatures = blocks.length;
    currentFeatureIndex = Math.max(0, Math.min(index, totalFeatures - 1));

    const targetBlock = blocks[currentFeatureIndex];
    const scrollContainer = document.getElementById('features-slider-wrapper');

    if (targetBlock && scrollContainer) {
        // Scroll to position that centers the feature
        const targetTop = targetBlock.offsetTop - scrollContainer.offsetTop;
        scrollContainer.scrollTo({
            top: targetTop,
            behavior: 'smooth'
        });

        // Update indicators
        updatePositionIndicators();

        // Update active feature for image switching
        document.querySelectorAll('.feature-text-group').forEach((item, idx) => {
            if (idx === currentFeatureIndex) {
                item.classList.add('active');
            } else {
                item.classList.remove('active');
            }
        });
    }
}

// Navigate prev/next
function navigateFeature(direction) {
    const newIndex = direction === 'next'
        ? currentFeatureIndex + 1
        : currentFeatureIndex - 1;
    navigateToFeature(newIndex);
}

// Update position indicators
function updatePositionIndicators() {
    const indicators = document.querySelectorAll('[data-indicator-index]');
    indicators.forEach((indicator, index) => {
        if (index === currentFeatureIndex) {
            indicator.className = 'w-6 h-2 rounded-full bg-purple-500 transition-all duration-300';
        } else {
            indicator.className = 'w-2 h-2 rounded-full bg-white/30 transition-all duration-300';
        }
    });
}
