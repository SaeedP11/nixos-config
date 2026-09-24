// Filled line graph of a sample history. `max` of 0 scales to the data.
import QtQuick
import qs.config

Canvas {
    id: root

    property var values: []
    property real max: 1
    property int capacity: 60
    property color tint: Theme.accent

    onValuesChanged: requestPaint()
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const v = values;
        if (v.length < 2)
            return;
        const top = max > 0 ? max : Math.max(1, ...v) * 1.15;
        const step = width / (capacity - 1);
        const x0 = width - (v.length - 1) * step;
        const y = s => height - Math.min(1, s / top) * (height - 2) - 1;

        ctx.beginPath();
        ctx.moveTo(x0, height);
        for (let i = 0; i < v.length; i++)
            ctx.lineTo(x0 + i * step, y(v[i]));
        ctx.lineTo(width, height);
        ctx.closePath();
        ctx.fillStyle = Theme.alpha(tint, 0.18);
        ctx.fill();

        ctx.beginPath();
        for (let i = 0; i < v.length; i++)
            i === 0 ? ctx.moveTo(x0, y(v[0])) : ctx.lineTo(x0 + i * step, y(v[i]));
        ctx.strokeStyle = tint;
        ctx.lineWidth = 1.6;
        ctx.stroke();
    }
}
