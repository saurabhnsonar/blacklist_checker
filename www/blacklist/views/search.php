
<?php require_once (__DIR__)."/head.php"; ?>
        <div class="content">
            <div class="container-fluid">
                <div class="row">
				
				
                    <div class="col-md-12">
                        <div class="card">
						
						<?php if ($searchActive) { ?>

                            <div class="header">
                                <h4 class="title">IPs List (<?=$numOfIps;?>)</h4>
                            </div>
                            <div class="content table-responsive table-full-width">
                                <table class="table table-striped">
                                    <thead>
										<tr>
											<th>
												<a href="<?=$sorter->sortUrl( array(0,1) );?>">
													<?=$sorter->sortView( array(0,1) );?> IP
												</a>
											</th>
											<th>
												<a href="<?=$sorter->sortUrl( array(2,3) );?>">
													<?=$sorter->sortView( array(2,3) );?> User ID
												</a>
											</th>
											<th>Category Name</th>
											<th>
												<a href="<?=$sorter->sortUrl( array(4,5) );?>">
													<?=$sorter->sortView( array(4,5) );?> Date
												</a>
											</th>
											<th>Actions</th>
										</tr>
                                    </thead>
                                    <tbody>
										<?php if ($numOfIps > 0) { ?>
											<?php foreach($records as $record) { ?>
												<?php if (isset($record['inBlackList']) && $record['inBlackList']) { ?>
												<tr class="danger">
												<?php }else if (isset($record['noAction']) && $record['noAction']) { ?>
												<tr class="warning">
												<?php } else { ?>
												<tr>
												<?php } ?>
													<td><?=$record['ip'];?></td>
													<td><?=isset($record['lastOwner'])?$record['lastOwner']:'';?></td>
													<td><?=isset($record['categoryName'])?$record['categoryName']:'';?></td>
													<td><?=isset($record['lastDate'])?$record['lastDate']:'';?></td>
													<td>
														<div class="btn-group" role="group" aria-label="...">
															<button type="button" class="btn btn-default" data-toggle="modal" data-ip="<?=$record['ip'];?>" data-target="#historyModal">History</button>
														</div>
													</td>
												</tr>
											<?php } ?>
										<?php } else { ?>
                                        <tr>
                                        	<td colspan=5 style="text-align: center;">No black listed IPs!</td>
                                        </tr>
										<?php } ?>
                                    </tbody>
                                </table>
								<?php if (!empty($pagination)) { ?>
									<?=$pagination;?>
								<?php } ?>
                            </div>
						
						<?php } else{ ?>
							
                            <div class="header">
                                <h4 class="title">Search</h4>
                            </div>
                            <div class="content">

                                <form method="get">

                                    <div class="row">
                                        <div class="col-md-4">
											<div class="row">
												<div class="col-md-10">
													<div class="form-group">
														<label>IP</label>
														<input type="text" name="ip" class="form-control border-input" placeholder="127.0.0.1 OR 127.0.0.*" value="">
													</div>
												</div>
											</div>
                                        </div>
                                        <div class="col-md-4">
											<div class="row">
												<div class="col-md-10">
													<div class="form-group">
														<label>User ID</label>
														<input type="text" name="userID" class="form-control border-input" placeholder="email@email.com" value="">
													</div>
												</div>
											</div>
                                        </div>
                                        <div class="col-md-4">
											<div class="row">
												<div class="col-md-10">
													<div class="form-group">
														<label>No action in X days</label>
														<input type="text" name="noActionDays" class="form-control border-input" placeholder="0 OR 3 OR 10" value="">
													</div>
												</div>
											</div>
                                        </div>
                                    </div>

                                    <div class="text-center">
                                        <button type="submit" class="btn btn-info btn-fill btn-wd" name="search" value="true">Search</button>
                                    </div>
                                    <div class="clearfix"></div>
                                </form>
							
                            </div>
							
						<?php } ?>
							
                        </div>
                    </div>


                </div>
            </div>
        </div>


<?php require_once (__DIR__)."/foot.php"; ?>

<style>
.loader {
	border: 16px solid #f3f3f3; /* Light grey */
	border-top: 16px solid #3498db; /* Blue */
	border-radius: 50%;
	width: 120px;
	height: 120px;
	animation: spin 2s linear infinite;
	margin: auto;
}

@keyframes spin {
	0% { transform: rotate(0deg); }
	100% { transform: rotate(360deg); }
}
</style>

<div class="modal fade" id="historyModal" tabindex="-1" role="dialog" aria-labelledby="historyModalLabel">
  <div class="modal-dialog" role="document">
    <div class="modal-content">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
        <h4 class="modal-title" id="historyModalLabel">IP '<span class="ipPlace"></span>' History</h4>
      </div>
      <div class="modal-body">
        <div class="loader"></div>
      </div>
    </div>
  </div>
</div>

<script>
$('#historyModal').on('show.bs.modal', function (event) {
	var button = $(event.relatedTarget);
	var _ip = button.data('ip');
	var modal = $(this);
	modal.find('.modal-title').find('.ipPlace').text(_ip);
	setTimeout(function() {
		$.post( "ipHistory", { ip: _ip }, function( _data ) {
			console.log(_data);
			if (typeof _data == "string") {
				modal.find('.modal-body').fadeOut("slow", function() {
					modal.find('.modal-body').find('.loader').remove();
					modal.find('.modal-body').html(_data);
					modal.find('.modal-body').fadeIn("fast");
				});
				return;
			}
			if (_data.length == 0) {
				modal.find('.modal-body').fadeOut("slow", function() {
					modal.find('.modal-body').find('.loader').remove();
					modal.find('.modal-body').html(
					'<div class="alert alert-info">'+
						'<span><b> Info - </b> This IP hasn\'t history...</span>'+
					'</div>'
					);
					modal.find('.modal-body').fadeIn("fast");
				});
			}else{
				var template = 
						'<div class="card">'+
                            '<div class="content table-responsive table-full-width">'+
                                '<table class="table table-striped">'+
                                    '<thead>'+
										'<tr>'+
											'<th>#</th>'+
											'<th>Action</th>'+
											'<th>Date</th>'+
										'</tr>'+
                                    '</thead>'+
                                    '<tbody>'+
                                    '</tbody>'+
                                '</table>'+
							'</div>'+
						'</div>';
				template = $(template);
				$.each(_data, function(key, data){
					template.find("tbody").append($(
						'<tr>'+
							'<td>'+data.id+'</td>'+
							'<td>'+data.action+'</td>'+
							'<td>'+data.date+'</td>'+
						'</tr>'
					));
				});
				modal.find('.modal-body').fadeOut("slow", function() {
					modal.find('.modal-body').find('.loader').remove();
					modal.find('.modal-body').append(template);
					modal.find('.modal-body').fadeIn("fast");
				});
			}
		}, "json")
		.fail(function() {
			modal.find('.modal-body').fadeOut("slow", function() {
				modal.find('.modal-body').find('.loader').remove();
				modal.find('.modal-body').html(
				'<div class="alert alert-danger">'+
					'<span><b> Error - </b> While loading IP history...</span>'+
				'</div>'
				);
				modal.find('.modal-body').fadeIn("fast");
			});
		});
	}, 1000);
});
$('#historyModal').on('hide.bs.modal', function (event) {
	var modal = $(this);
	modal.find('.modal-body').html('<div class="loader"></div>');
});
</script>
