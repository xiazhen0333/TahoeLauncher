// SPDX-License-Identifier: GPL-2.0-or-later
#include <KWindowEffects>
#include <QQmlExtensionPlugin>
#include <QQuickItem>
#include <QQuickWindow>
#include <QRegion>
#include <QTimer>
#include <QPointer>
#include <QEvent>

// Use the rendered SVG's mask directly, without Plasma Dialog's theme shadow.
class GlassEffects : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(QQuickItem *maskItem READ maskItem WRITE setMaskItem NOTIFY maskItemChanged)
    Q_PROPERTY(bool blurEnabled READ blurEnabled WRITE setBlurEnabled NOTIFY blurEnabledChanged)
    Q_PROPERTY(QRegion blurRegion READ blurRegion NOTIFY blurRegionChanged)
public:
    GlassEffects()
    {
        connect(this, &QQuickItem::windowChanged, this, [this](QQuickWindow *window) {
            if (m_window) {
                m_window->removeEventFilter(this);
                KWindowEffects::enableBlurBehind(m_window, false);
                disconnect(m_window, nullptr, this, nullptr);
            }
            m_window = window;
            if (window) {
                window->installEventFilter(this);
                connect(window, &QWindow::visibleChanged, this, &GlassEffects::scheduleUpdate);
                connect(window, &QWindow::widthChanged, this, &GlassEffects::scheduleUpdate);
                connect(window, &QWindow::heightChanged, this, &GlassEffects::scheduleUpdate);
            }
            scheduleUpdate();
        });
    }
    ~GlassEffects() override
    {
        if (m_window)
            KWindowEffects::enableBlurBehind(m_window, false);
    }
    QQuickItem *maskItem() const { return m_maskItem; }
    void setMaskItem(QQuickItem *item)
    {
        if (item == m_maskItem)
            return;
        if (m_maskItem)
            disconnect(m_maskItem, nullptr, this, nullptr);
        m_maskItem = item;
        if (item)
            connect(item, SIGNAL(maskChanged()), this, SLOT(scheduleUpdate()));
        emit maskItemChanged();
        scheduleUpdate();
    }
    bool blurEnabled() const { return m_blurEnabled; }
    void setBlurEnabled(bool enabled)
    {
        if (enabled == m_blurEnabled)
            return;
        m_blurEnabled = enabled;
        emit blurEnabledChanged();
        scheduleUpdate();
    }
    QRegion blurRegion() const { return m_region; }
protected:
    bool eventFilter(QObject *object, QEvent *event) override
    {
        // Plasma Dialog clears blur in its Wayland expose and resize handlers.
        // Reapply our mask after those handlers, when the surface is ready.
        if (object == m_window && (event->type() == QEvent::Expose || event->type() == QEvent::Resize))
            scheduleUpdate();
        return QQuickItem::eventFilter(object, event);
    }
signals:
    void maskItemChanged();
    void blurEnabledChanged();
    void blurRegionChanged();
private slots:
    void scheduleUpdate()
    {
        if (m_pending)
            return;
        m_pending = true;
        QTimer::singleShot(0, this, [this] {
            m_pending = false;
            m_region = m_maskItem ? m_maskItem->property("mask").value<QRegion>() : QRegion();
            if (m_maskItem)
                m_region.translate(m_maskItem->mapToScene(QPointF()).toPoint());
            emit blurRegionChanged();
            if (m_window) {
                KWindowEffects::enableBlurBehind(m_window,
                    m_blurEnabled && m_window->isVisible() && !m_region.isEmpty(), m_region);
                // Wayland applies the region with the next surface commit.
                m_window->update();
            }
        });
    }
private:
    QPointer<QQuickWindow> m_window;
    QPointer<QQuickItem> m_maskItem;
    QRegion m_region;
    bool m_blurEnabled = false;
    bool m_pending = false;
};

class TahoeGlassPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override { qmlRegisterType<GlassEffects>(uri, 1, 0, "GlassEffects"); }
};
#include "plugin.moc"
