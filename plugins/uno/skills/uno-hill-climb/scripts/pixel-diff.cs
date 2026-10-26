#:package SixLabors.ImageSharp@3.1.*
// pixel-diff.cs: a .NET 10 file-based app. Compares two screenshots and fails when they differ
// beyond tolerance. Used by uno-hill-climb as the visual guard.
//
//   dotnet run <path-to-skill>/scripts/pixel-diff.cs -- <baseline.png> <candidate.png>
//       [--tolerance 0.5] [--delta 8] [--mask x,y,w,h ...] [--out diff.png]
//
// Exit codes: 0 within tolerance · 1 over tolerance · 2 size mismatch or bad arguments.
// Prints: changed=<pct> maxDelta=<n> pixels=<changed>/<counted>

using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;

var positional = new List<string>();
double tolerance = 0.5;   // percent of counted pixels allowed to differ
int delta = 8;            // per-channel difference that counts as "changed"
var masks = new List<Rectangle>();
string? outPath = null;

for (var i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--tolerance": tolerance = double.Parse(args[++i], System.Globalization.CultureInfo.InvariantCulture); break;
        case "--delta": delta = int.Parse(args[++i]); break;
        case "--out": outPath = args[++i]; break;
        case "--mask":
            var p = args[++i].Split(',').Select(int.Parse).ToArray();
            if (p.Length != 4) { Console.Error.WriteLine("mask must be x,y,w,h"); return 2; }
            masks.Add(new Rectangle(p[0], p[1], p[2], p[3]));
            break;
        default: positional.Add(args[i]); break;
    }
}

if (positional.Count != 2)
{
    Console.Error.WriteLine("usage: pixel-diff <baseline.png> <candidate.png> [--tolerance 0.5] [--delta 8] [--mask x,y,w,h ...] [--out diff.png]");
    return 2;
}

using var a = Image.Load<Rgba32>(positional[0]);
using var b = Image.Load<Rgba32>(positional[1]);

if (a.Width != b.Width || a.Height != b.Height)
{
    Console.Error.WriteLine($"size mismatch: {a.Width}x{a.Height} vs {b.Width}x{b.Height}");
    return 2;
}

long counted = 0, changed = 0; int maxDelta = 0;
using var diff = outPath is null ? null : new Image<Rgba32>(a.Width, a.Height);

for (var y = 0; y < a.Height; y++)
{
    for (var x = 0; x < a.Width; x++)
    {
        var masked = false;
        foreach (var m in masks) if (m.Contains(x, y)) { masked = true; break; }

        var pa = a[x, y]; var pb = b[x, y];
        var d = Math.Max(Math.Max(Math.Abs(pa.R - pb.R), Math.Abs(pa.G - pb.G)), Math.Abs(pa.B - pb.B));

        if (masked)
        {
            if (diff is not null) diff[x, y] = new Rgba32(60, 60, 90, 255);
            continue;
        }

        counted++;
        var isChanged = d > delta;
        if (isChanged) changed++;
        if (d > maxDelta) maxDelta = d;

        if (diff is not null)
        {
            var g = (byte)(0.299 * pa.R + 0.587 * pa.G + 0.114 * pa.B);
            diff[x, y] = isChanged ? new Rgba32(255, 40, 40, 255) : new Rgba32((byte)(g / 3), (byte)(g / 3), (byte)(g / 3), 255);
        }
    }
}

var pct = counted == 0 ? 0 : 100.0 * changed / counted;
Console.WriteLine(string.Create(System.Globalization.CultureInfo.InvariantCulture,
    $"changed={pct:F3}% maxDelta={maxDelta} pixels={changed}/{counted}"));

if (diff is not null) diff.Save(outPath!);

return pct <= tolerance ? 0 : 1;
