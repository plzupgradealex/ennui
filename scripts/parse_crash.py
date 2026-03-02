#!/usr/bin/env python3
"""Parse macOS .ips crash reports and extract useful info."""
import json, sys, os, glob

reports_dir = os.path.expanduser("~/Library/Logs/DiagnosticReports")
files = sorted(glob.glob(os.path.join(reports_dir, "Ennui-*.ips")), reverse=True)

if not files:
    print("No Ennui crash reports found.")
    sys.exit(0)

for path in files[:3]:  # Analyze last 3 crashes
    print(f"\n{'='*60}")
    print(f"File: {os.path.basename(path)}")
    print(f"{'='*60}")
    
    with open(path) as f:
        lines = f.readlines()
    
    # .ips files have a header JSON line, then the payload JSON
    if len(lines) < 2:
        print("  (too short)")
        continue
    
    try:
        data = json.loads(lines[1] if len(lines) > 1 else lines[0])
    except json.JSONDecodeError:
        # Try joining all lines after the first
        try:
            data = json.loads("".join(lines[1:]))
        except json.JSONDecodeError:
            try:
                data = json.loads("".join(lines))
            except:
                print("  (could not parse JSON)")
                continue

    # Exception info
    exc = data.get("exception", {})
    print(f"Exception Type: {exc.get('type', '?')} ({exc.get('signal', '?')})")
    if 'subtype' in exc:
        print(f"Exception Subtype: {exc['subtype']}")
    
    term = data.get("termination", {})
    if term:
        print(f"Termination: {term.get('code', '?')} - {term.get('indicator', '?')}")
        if 'byProc' in term:
            print(f"  By Process: {term['byProc']}")
    
    # ASI (Application Specific Info)
    asi = data.get("asi", {})
    if asi:
        for k, v in asi.items():
            if isinstance(v, list):
                for line in v:
                    print(f"ASI: {line}")
            else:
                print(f"ASI: {v}")
    
    # Last exception backtrace
    leb = data.get("lastExceptionBacktrace", [])
    if leb:
        print(f"\nLast Exception Backtrace:")
        for i, frame in enumerate(leb[:15]):
            sym = frame.get("symbol", "???")
            src = frame.get("sourceFile", "")
            print(f"  {i}: {sym}" + (f" ({src})" if src else ""))
    
    # Faulting thread
    ft_idx = data.get("faultingThread", 0)
    threads = data.get("threads", [])
    if ft_idx < len(threads):
        thread = threads[ft_idx]
        frames = thread.get("frames", [])
        print(f"\nCrashing Thread {ft_idx} ({thread.get('name', 'unnamed')}):")
        for i, frame in enumerate(frames[:25]):
            sym = frame.get("symbol", "???")
            src = frame.get("sourceFile", "")
            print(f"  {i}: {sym}" + (f" ({src})" if src else ""))
