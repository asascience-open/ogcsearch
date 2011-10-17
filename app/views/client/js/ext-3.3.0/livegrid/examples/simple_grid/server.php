<?php
/**
 * This is a very simple script for delivering sorted/spliced data
 * to ths client. It's intended use is for demonstrational purposes
 * only!
 *
 * @author Thorsten Suckow-Homberg <ts@siteartwork.de>
 */

$sort  = $_POST['sort'];
$dir   = $_POST['dir'];
$start = $_POST['start'];
$limit = $_POST['limit'];

require_once './data.php';

$data = unserialize($me);
$totalCount = count($data);



function nr_cmp($a, $b)
{
    if ((int)$a['number'] == (int)$b['number']) {
        return 0;
    }
    return ((int)$a['number'] < (int)$b['number']) ? -1 : 1;
}

function date_cmp($a, $b)
{
    if ((int)$a['date'] == (int)$b['date']) {
        return 0;
    }
    return ((int)$a['date'] < (int)$b['date']) ? -1 : 1;
}

function my_strcmp($a, $b)
{
    return strcmp($a['text'], $b['text']);
}

switch ($sort) {
    case 'number':
        usort($data, 'nr_cmp');
    break;

    case 'date':
        usort($data, 'date_cmp');
    break;

    case 'text':
        usort($data, 'my_strcmp');
    break;
}

if ($dir == 'DESC') {
    $data = array_reverse($data);
}

$data = array_splice($data, $start, $limit);

for ($i = 0, $len = count($data); $i < $len; $i++) {
    $data[$i]['date'] = date("Y-m-d H:i:s", $data[$i]['date']);
}

$response = array(
    'data'       => $data,
    'version'    => 1,
    'totalCount' => $totalCount

);


if (function_exists('json_encode')) {
    $json = json_encode($response);
} else {
    require_once 'Zend/Json.php';
    $json = Zend_Json::encode($response);
}

echo $json;

die();

?>