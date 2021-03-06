package com.plugin.leosplugin;

import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;

import org.tensorflow.lite.Interpreter;

import java.io.FileInputStream;
import java.io.IOException;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * LeospluginPlugin
 */
public class LeospluginPlugin<T> implements MethodCallHandler {

    Class x = Double.TYPE;


    private final Registrar mRegistrar;

    private Map<String, Interpreter> models = null;

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "leosplugin");
        channel.setMethodCallHandler(new LeospluginPlugin(registrar));
    }

    private LeospluginPlugin(Registrar registrar) {
        this.mRegistrar = registrar;
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        if (call.method.equals("loadModel")) {
            String res = null;
            try {
                res = loadModel((HashMap) call.arguments);
            } catch (IOException e) {
                e.printStackTrace();
            }
            result.success(res);
        } else if (call.method.equals("run")) {
            result.success(run((HashMap) call.arguments));
        } else if (call.method.equals("inputShape")) {
            int[] res = inputShape((HashMap) call.arguments);
            if (res != null) {
                result.success(res);
            } else {
                result.error("ERR", "Kein Model geladen", null);
            }
        } else if (call.method.equals("dispose")) {
            result.success(this.dispose());
        } else {
            result.notImplemented();
        }
    }


    /**
     * Laedt das Model
     *
     * @param args
     * @return succes wenn das Model geladen wurde
     * @throws IOException
     */
    private String loadModel(HashMap args) throws IOException {
        if (models == null) {
            models = new HashMap<>();
        }
        String model = args.get("model").toString();
        AssetManager assetManager = mRegistrar.context().getAssets();
        String key = mRegistrar.lookupKeyForAsset(model);
        AssetFileDescriptor fileDescriptor = assetManager.openFd(key);
        FileInputStream inputStream = new FileInputStream(fileDescriptor.getFileDescriptor());
        FileChannel fileChannel = inputStream.getChannel();
        long startOffset = fileDescriptor.getStartOffset();
        long declaredLength = fileDescriptor.getDeclaredLength();
        MappedByteBuffer buffer = fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength);

        int numThreads = (int) args.get("numThreads");
        final Interpreter.Options tfliteOptions = new Interpreter.Options();
        tfliteOptions.setNumThreads(numThreads);
        if (models.containsKey(args.get("name").toString())) {
            return "error";
        }
        models.put(args.get("name").toString(), new Interpreter(buffer, tfliteOptions));
        return "success";
    }


    /**
     * Diese Methode kriegt ein Image als Double-Array übergeben.
     * Die listen Elemente sind in dieser Reihenfolge:
     * [x,y,Farbe]
     * [0,0,r],[0,0,g],[0,0,b],[1,0,r],....
     * Durch eine Hilfsmethode wird dieses Array in ein 4-Dimensionales-Array  aus floats umgewandelt,
     * welches als Input für den Tensor benutzt werden kann.
     * Format: [1][x][y][rgb]
     * Der Output wird nun berechnet und wieder zurück zu einem 1-Dimensionales-Byte-Array
     * konvertiert, welches dann im Dart-Code zu einem Image umgewandelt werden kann.
     *
     * @param args Übergebene Argumente der Dart-API
     * @return Output des Tensors im richtigen Format
     */
    private int[] run(HashMap args) {
        double[] doubles = (double[]) args.get("floats");
        int[] result;
        int[] inputShape = inputShape(args);
        int[] outputShape = outputShape(args);
        Object input, output;
        input = getInput6d(doubles, args, inputShape);


        output = new float[outputShape[0]][outputShape[1]][outputShape[2]][outputShape[3]];
        models.get(args.get("name").toString()).run(input, output);
        result = outputToByteArray4d(output, outputShape);

        return result;
    }

    /**
     * Wandelt ein Double-Array dieses Formates:
     * [x,y,Farbe]
     * [0,0,r],[0,0,g],[0,0,b],[1,0,r],....
     * in ein Float-Array um,
     * welches als Input für den Tensor benutzt werden kann.
     * Format: [1][x][y][rgb]
     *
     * @param doubles Image als double Werte
     * @return input für den Tensor
     */
    private float[][][][] getInput4d(double[] doubles, HashMap args, int[] shape) {
        int length = 1;
        for (int s : shape) {
            length *= s;
        }

        if (length != doubles.length) {
            return null;
        }

        float[][][][] result = new float[shape[0]][shape[1]][shape[2]][shape[3]];
        int idx = 0;
        for (int a = 0; a < shape[0]; a++) {
            for (int y = 0; y < shape[1]; y++) {
                for (int x = 0; x < shape[2]; x++) {
                    for (int c = 0; c < shape[3]; c++) {
                        result[a][y][x][c] = (float) doubles[idx++];
                    }
                }
            }
        }

        return result;
    }

    /**
     * Wandelt ein Double-Array dieses Formates:
     * [x,y,Farbe]
     * [0,0,r],[0,0,g],[0,0,b],[1,0,r],....
     * in ein Float-Array um,
     * welches als Input für den Tensor benutzt werden kann.
     * Format: [1][x][y][rgb]
     *
     * @param doubles Image als double Werte
     * @return input für den Tensor
     */
    private float[][][] getInput3d(double[] doubles, HashMap args, int[] shape) {
        int length = 1;
        for (int s : shape) {
            length *= s;
        }

        if (length != doubles.length) {
            return null;
        }

        float[][][] result = new float[shape[0]][shape[1]][shape[2]];
        int idx = 0;
        for (int y = 0; y < shape[0]; y++) {
            for (int x = 0; x < shape[1]; x++) {
                for (int c = 0; c < shape[2]; c++) {
                    result[y][x][c] = (float) doubles[idx++];
                }
            }
        }

        return result;
    }

    /**
     * Wandelt ein Double-Array dieses Formates:
     * [x,y,Farbe]
     * [0,0,r],[0,b],[0,0,g],[0,1,0,r],....
     * in ein Float-Array um,
     * welches als Input für den Tensor benutzt werden kann.
     * Format: [1][x][y][rgbrgb]
     *
     * @param doubles Image als double Werte
     * @return input für den Tensor
     */
    private float[][][][] getInput6d(double[] doubles, HashMap args, int[] shape) {
        int length = 1;
        for (int s : shape) {
            length *= s;
        }

        if (length != doubles.length) {
            return null;
        }
        float[][][][] result = new float[shape[0]][shape[1]][shape[2]][shape[3]];
        int idx = 0;
        int shapediv2 = length / 2;
        for (int y = 0; y < shape[0]; y++) {
            for (int x = 0; x < shape[1]; x++) {
            for (int z = 0; z < shape[2]; z++) {
                for(int c = 0; c < 3; c++) {
                    result[y][x][z][c] = (float) doubles[idx];
                    result[y][x][z][c + 3] = (float) doubles[shapediv2 + idx++];
                }
                }
            }
        }

        return result;
    }


    /**
     * Wandelt den Output des Tensors wieder in eine Liste zurück,
     * die zurückgesendet werden kann.
     *
     * @param outputO Output des Tensors
     * @return Double-Array
     */
    private int[] outputToByteArray4d(Object outputO, int[] shape) {
        float[][][][] output = (float[][][][]) outputO;
        double[] resultAsDouble = new double[shape[0] * shape[1] * shape[2] * shape[3]];
        int[] result = new int[resultAsDouble.length];
        int idx = 0;
        for (int a = 0; a < shape[0]; a++) {
            for (int y = 0; y < shape[1]; y++) {
                for (int x = 0; x < shape[2]; x++) {
                    for (int c = 0; c < shape[3]; c++) {
                        resultAsDouble[idx] = output[a][y][x][c]; // * 255;
                        if ((resultAsDouble[idx] > 255)) {
                            result[idx] = 255;
                        } else if (resultAsDouble[idx] < 0) {
                            result[idx] = 0;
                        } else {
                            result[idx] = (int) resultAsDouble[idx];
                        }
                        idx++;
                    }
                }
            }
        }
        return result;
    }

    /**
     * Wandelt den Output des Tensors wieder in eine Liste zurück,
     * die zurückgesendet werden kann.
     *
     * @param outputO Output des Tensors
     * @return Double-Array
     */
    private byte[] outputToByteArray3d(Object outputO, int[] shape) {
        float[][][] output = (float[][][]) outputO;
        double[] resultAsDouble = new double[Arrays.stream(shape).sum()];
        byte[] result = new byte[resultAsDouble.length];
        int idx = 0;
        for (int a = 0; a < shape[0]; a++) {
            for (int y = 0; y < shape[1]; y++) {
                for (int x = 0; x < shape[2]; x++) {
                    resultAsDouble[idx] = output[a][y][x] * 255;
                    if ((resultAsDouble[idx] > 255)) {
                        result[idx] = (byte) 255;
                    } else if (resultAsDouble[idx] < 0) {
                        result[idx] = 0;
                    } else {
                        result[idx] = (byte) resultAsDouble[idx];
                    }
                    idx++;
                }
            }
        }



        return result;
    }

    /**
     * Wandelt den Output des Tensors wieder in eine Liste zurück,
     * die zurückgesendet werden kann.
     *
     * @param outputO Output des Tensors
     * @return Double-Array
     */
    private byte[] outputToByteArray2d(Object outputO, int[] shape) {
        float[][] output = (float[][]) outputO;
        double[] resultAsDouble = new double[Arrays.stream(shape).sum()];
        byte[] result = new byte[resultAsDouble.length];
        int idx = 0;
        for (int a = 0; a < shape[0]; a++) {
            for (int y = 0; y < shape[1]; y++) {
                resultAsDouble[idx] = output[a][y] * 255;
                if ((resultAsDouble[idx] > 255)) {
                    result[idx] = (byte) 255;
                } else if (resultAsDouble[idx] < 0) {
                    result[idx] = 0;
                } else {
                    result[idx] = (byte) resultAsDouble[idx];
                }
                idx++;
            }
        }


        return result;
    }

    /**
     * Wandelt den Output des Tensors wieder in eine Liste zurück,
     * die zurückgesendet werden kann.
     *
     * @param outputO Output des Tensors
     * @return Double-Array
     */
    private byte[] outputToByteArray1d(Object outputO, int[] shape) {
        float[] output = (float[]) outputO;
        double[] resultAsDouble = new double[Arrays.stream(shape).sum()];
        byte[] result = new byte[resultAsDouble.length];
        int idx = 0;
        for (int a = 0; a < shape[0]; a++) {
            resultAsDouble[idx] = output[a] * 255;
            if ((resultAsDouble[idx] > 255)) {
                result[idx] = (byte) 255;
            } else if (resultAsDouble[idx] < 0) {
                result[idx] = 0;
            } else {
                result[idx] = (byte) resultAsDouble[idx];
            }
            idx++;
        }

        return result;
    }

    /**
     * Gibt den Shape eines Models
     *
     * @param args der Names des Models
     * @return Shape
     */
    private int[] inputShape(HashMap args) {
        return models.get(args.get("name").toString()) == null ? null : models.get(args.get("name").toString()).getInputTensor(0).shape();
    }

    /**
     * Gibt den Shape eines Models
     *
     * @param args der Names des Models
     * @return Shape
     */
    private int[] outputShape(HashMap args) {
        return models.get(args.get("name").toString()) == null ? null : models.get(args.get("name").toString())
                .getOutputTensor(models.get(args.get("name").toString()).getInputTensorCount() - 1).shape();
    }


    /**
     * Schließt alle Interpreter
     *
     * @return "success", wenn kein Error
     */
    private String dispose() {
        models.values().forEach(Interpreter::close);
        return "success";
    }


}


